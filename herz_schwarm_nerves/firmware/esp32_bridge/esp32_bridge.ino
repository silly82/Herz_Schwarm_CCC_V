/**
 * Herz-Schwarm ESP32 Bridge Firmware
 *
 * USB-Serial → ESP-NOW Bridge für den Nerves-Controller am Raspberry Pi.
 * Empfängt JSON-Kommandos über Serial (115200 Baud, newline-delimited),
 * baut SyncPackets und broadcastet sie auf Kanal 13.
 *
 * Protokoll (Pi → Bridge):
 *   {"cmd":"effect","mode":5,"seq":42}
 *   {"cmd":"effect","mode":7,"seq":43,"beatCounter":65280}
 *   {"cmd":"status","seq":44}
 *   {"cmd":"peers","seq":45}
 *   {"cmd":"identify","mac":"A0:F2:62:EC:3B:B4","seq":46}
 *
 * Protokoll (Bridge → Pi):
 *   {"evt":"ack","seq":42}
 *   {"evt":"pong","peers":5,"uptime":12345}
 *   {"evt":"peer","mac":"A0:F2:62:EC:3B:B4","rssi":-74,"fw":"1.3.0","age":40}   (je Station)
 *   {"evt":"peers","seq":45,"n":5}                                             (Ende der Liste)
 *   {"evt":"log","msg":"bridge ready"}
 *   {"evt":"err","msg":"json parse failed"}
 *
 * Protokoll (Station → Bridge, ESP-NOW binär, kein JSON):
 *   Badges broadcasten laufend SyncPackets; während eines Effekts mit
 *   dessen virusID. Die Bridge wertet das als implizites Ack (kein extra
 *   Paket nötig, funktioniert mit jeder Badge-Firmware). Alternativ wird
 *   ein explizites AckPacket (magic_id, virusID) akzeptiert. Die Bridge
 *   broadcastet ein SyncPacket bis zu MAX_RETRIES mal erneut, wenn nicht
 *   alle bekannten (kürzlich aktiven) Stationen innerhalb von
 *   ACK_TIMEOUT_MS bestätigt haben. Stationen, die länger als
 *   STATION_STALE_MS nichts gesendet haben, gelten als offline und
 *   blockieren keine Retries mehr.
 *
 * Benötigt: ArduinoJson >= 7 (Library Manager: "ArduinoJson" by Benoit Blanchon)
 */

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <ArduinoJson.h>

#define CCC_CHANNEL     13
#define MAGIC_ID        0x421337CC
#define BRIDGE_FW_MAJOR 0
#define BRIDGE_FW_MINOR 2
#define BRIDGE_FW_PATCH 0

#define MAX_JSON_LEN    256
#define SERIAL_BAUD     115200

#define MAX_STATIONS      32     // Obergrenze gleichzeitig bekannter Stationen; veraltete Slots werden wiederverwendet
#define ACK_TIMEOUT_MS    150    // Wartezeit auf Acks bevor ggf. erneut gebroadcastet wird
#define MAX_RETRIES       2      // max. Re-Broadcasts pro Effekt (1 initial + 2 Retries)
#define STATION_STALE_MS  5000   // Station gilt nach dieser Inaktivität als offline (Badges senden mit 20 Hz)
#define SYNC_PACKET_LEGACY_LEN 13
#define SYNC_MODE_IDENTIFY 9     // "Badge finden": SyncPacket + 6 Byte Ziel-MAC (Badge-FW >= 1.3)
#define IDENTIFY_REPEATS   3     // Funk ist verlustbehaftet; Badge dedupliziert per virusID

struct __attribute__((packed)) SyncPacket {
    uint32_t magic_id;
    uint32_t beatCounter;
    uint32_t virusID;
    uint8_t  mode;
    uint8_t  ver_major;
    uint8_t  ver_minor;
    uint8_t  ver_rel;
    uint8_t  ver_dbg;
};

struct __attribute__((packed)) AckPacket {
    uint32_t magic_id;
    uint32_t virusID;
};

struct Station {
    uint8_t  mac[6];
    uint32_t lastSeenMs;
    bool     ackedRound;
    int8_t   rssi;
    bool     hasVer;     // false bei 13-Byte-Paketen alter Firmware
    uint8_t  ver[3];
};

static Station knownStations[MAX_STATIONS];
static int knownStationsCount = 0;
// Schützt knownStations + pending* zwischen WiFi-Task (onDataRecv) und loop()
static portMUX_TYPE stationMux = portMUX_INITIALIZER_UNLOCKED;

// Aktuell in Zustellung befindliches SyncPacket (Retry-Zustandsmaschine)
static SyncPacket pendingPkt;
static bool       pendingActive = false;
static uint32_t   pendingSentAt = 0;
static uint8_t    pendingRetries = 0;

static uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static char lineBuf[MAX_JSON_LEN];
static int linePos = 0;

static void sendJson(const JsonDocument &doc) {
    char out[256];
    serializeJson(doc, out, sizeof(out));
    Serial.println(out);
}

static void sendAck(uint32_t seq) {
    JsonDocument doc;
    doc["evt"] = "ack";
    doc["seq"] = seq;
    sendJson(doc);
}

static void sendError(const char *msg) {
    JsonDocument doc;
    doc["evt"] = "err";
    doc["msg"] = msg;
    sendJson(doc);
}

static void sendLog(const char *msg) {
    JsonDocument doc;
    doc["evt"] = "log";
    doc["msg"] = msg;
    sendJson(doc);
}

// Findet eine Station per MAC oder legt sie neu an (ggf. in einem veralteten
// Slot). Gibt -1 zurueck wenn alle Slots aktiv belegt sind. Aufruf unter stationMux.
static int findOrAddStation(const uint8_t *mac) {
    uint32_t now = millis();
    int staleSlot = -1;
    for (int i = 0; i < knownStationsCount; i++) {
        if (memcmp(knownStations[i].mac, mac, 6) == 0) {
            return i;
        }
        if (staleSlot < 0 && now - knownStations[i].lastSeenMs > STATION_STALE_MS) {
            staleSlot = i;
        }
    }
    int idx;
    if (knownStationsCount < MAX_STATIONS) {
        idx = knownStationsCount++;
    } else if (staleSlot >= 0) {
        idx = staleSlot;
    } else {
        return -1;
    }
    memcpy(knownStations[idx].mac, mac, 6);
    knownStations[idx].ackedRound = false;
    knownStations[idx].lastSeenMs = now;
    knownStations[idx].hasVer = false;
    return idx;
}

static int countAliveStations() {
    uint32_t now = millis();
    int count = 0;
    for (int i = 0; i < knownStationsCount; i++) {
        if (now - knownStations[i].lastSeenMs <= STATION_STALE_MS) {
            count++;
        }
    }
    return count;
}

static int countAckedRound() {
    int count = 0;
    for (int i = 0; i < knownStationsCount; i++) {
        if (knownStations[i].ackedRound) {
            count++;
        }
    }
    return count;
}

static void resetAckRound() {
    for (int i = 0; i < knownStationsCount; i++) {
        knownStations[i].ackedRound = false;
    }
}

// ESP-NOW-Recv-Callback (WiFi-Task, Core 0). Zwei Paketarten:
//  - SyncPacket (>= 13 Byte): regulärer Badge-Broadcast. Markiert die Station
//    als lebendig. Trägt er die virusID des laufenden Effekts, hat das Badge
//    den Effekt übernommen und sendet ihn weiter → zählt als Ack.
//  - AckPacket (8 Byte): explizites Ack, für Stationen, die eins senden.
static void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
    if (len < (int)sizeof(uint32_t) || *(const uint32_t *)data != MAGIC_ID) {
        return;
    }

    uint32_t virusID;
    const SyncPacket *sp = nullptr;
    if (len == sizeof(AckPacket)) {
        virusID = ((const AckPacket *)data)->virusID;
    } else if (len >= SYNC_PACKET_LEGACY_LEN) {
        sp = (const SyncPacket *)data;
        virusID = sp->virusID;
    } else {
        return;
    }

    portENTER_CRITICAL(&stationMux);
    int idx = findOrAddStation(info->src_addr);
    if (idx >= 0) {
        knownStations[idx].lastSeenMs = millis();
        knownStations[idx].rssi = info->rx_ctrl ? info->rx_ctrl->rssi : 0;
        if (sp && len >= (int)sizeof(SyncPacket)) {
            knownStations[idx].hasVer = true;
            knownStations[idx].ver[0] = sp->ver_major;
            knownStations[idx].ver[1] = sp->ver_minor;
            knownStations[idx].ver[2] = sp->ver_rel;
        }
        if (pendingActive && virusID == pendingPkt.virusID) {
            knownStations[idx].ackedRound = true;
        }
    }
    portEXIT_CRITICAL(&stationMux);
}

static void sendPong() {
    JsonDocument doc;
    doc["evt"] = "pong";
    portENTER_CRITICAL(&stationMux);
    int alive = countAliveStations();
    portEXIT_CRITICAL(&stationMux);
    doc["peers"] = alive;
    doc["uptime"] = (uint32_t)(millis() / 1000);
    doc["free_heap"] = ESP.getFreeHeap();
    sendJson(doc);
}

// Eine Zeile pro aktiver Station, danach {"evt":"peers","n":…} als Listenende.
static void sendPeers(uint32_t seq) {
    Station snap[MAX_STATIONS];
    int n = 0;
    uint32_t now;
    portENTER_CRITICAL(&stationMux);
    now = millis();
    for (int i = 0; i < knownStationsCount; i++) {
        if (now - knownStations[i].lastSeenMs <= STATION_STALE_MS) {
            snap[n++] = knownStations[i];
        }
    }
    portEXIT_CRITICAL(&stationMux);

    for (int i = 0; i < n; i++) {
        char mac[18], fw[12];
        snprintf(mac, sizeof(mac), "%02X:%02X:%02X:%02X:%02X:%02X",
                 snap[i].mac[0], snap[i].mac[1], snap[i].mac[2], snap[i].mac[3], snap[i].mac[4], snap[i].mac[5]);
        if (snap[i].hasVer) {
            snprintf(fw, sizeof(fw), "%u.%u.%u", snap[i].ver[0], snap[i].ver[1], snap[i].ver[2]);
        } else {
            strcpy(fw, "?");
        }
        JsonDocument doc;
        doc["evt"] = "peer";
        doc["mac"] = mac;
        doc["rssi"] = snap[i].rssi;
        doc["fw"] = fw;
        doc["age"] = now - snap[i].lastSeenMs;
        sendJson(doc);
    }
    JsonDocument end;
    end["evt"] = "peers";
    end["seq"] = seq;
    end["n"] = n;
    sendJson(end);
}

static bool parseMac(const char *s, uint8_t out[6]) {
    unsigned v[6];
    if (sscanf(s, "%2x:%2x:%2x:%2x:%2x:%2x", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5]) != 6) return false;
    for (int i = 0; i < 6; i++) out[i] = (uint8_t)v[i];
    return true;
}

// Nur das Badge mit dieser STA-MAC blinkt ~10 s grün. Nicht über die Ack/Retry-
// Maschine: es antwortet nur ein einziges Badge, die anderen würden Retries auslösen.
static bool sendIdentify(const uint8_t *mac) {
    SyncPacket pkt = {};
    pkt.magic_id = MAGIC_ID;
    pkt.virusID = (uint32_t)esp_random();
    pkt.mode = SYNC_MODE_IDENTIFY;
    pkt.ver_major = BRIDGE_FW_MAJOR;
    pkt.ver_minor = BRIDGE_FW_MINOR;
    pkt.ver_rel = BRIDGE_FW_PATCH;
    uint8_t buf[sizeof(SyncPacket) + 6];
    memcpy(buf, &pkt, sizeof(pkt));
    memcpy(buf + sizeof(pkt), mac, 6);
    bool ok = false;
    for (int i = 0; i < IDENTIFY_REPEATS; i++) {
        if (i) delay(15);
        ok |= (esp_now_send(broadcastMac, buf, sizeof(buf)) == ESP_OK);
    }
    return ok;
}

static void handleCommand(const char *json) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, json);
    if (err) {
        sendError(err.c_str());
        return;
    }

    const char *cmd = doc["cmd"] | "";
    uint32_t seq = doc["seq"] | 0;

    if (strcmp(cmd, "effect") == 0) {
        uint8_t mode = doc["mode"] | 0;
        uint32_t virusID = doc["virusID"] | (uint32_t)esp_random();
        uint32_t beatCounter = doc["beatCounter"] | (uint32_t)millis();

        if (mode < 1 || mode > 8) {
            sendError("mode must be 1-8");
            return;
        }

        SyncPacket pkt = {};
        pkt.magic_id = MAGIC_ID;
        pkt.beatCounter = beatCounter;
        pkt.virusID = virusID;
        pkt.mode = mode;
        pkt.ver_major = BRIDGE_FW_MAJOR;
        pkt.ver_minor = BRIDGE_FW_MINOR;
        pkt.ver_rel = BRIDGE_FW_PATCH;
        pkt.ver_dbg = 0;

        esp_err_t res = esp_now_send(broadcastMac, (uint8_t *)&pkt, sizeof(pkt));
        if (res == ESP_OK) {
            portENTER_CRITICAL(&stationMux);
            resetAckRound();
            pendingPkt = pkt;
            pendingActive = true;
            pendingSentAt = millis();
            pendingRetries = 0;
            portEXIT_CRITICAL(&stationMux);
            sendAck(seq);
        } else {
            JsonDocument e;
            e["evt"] = "err";
            e["seq"] = seq;
            e["msg"] = "esp_now_send failed";
            sendJson(e);
        }
    }
    else if (strcmp(cmd, "status") == 0) {
        sendPong();
    }
    else if (strcmp(cmd, "peers") == 0) {
        sendPeers(seq);
    }
    else if (strcmp(cmd, "identify") == 0) {
        uint8_t mac[6];
        if (!parseMac(doc["mac"] | "", mac)) {
            sendError("mac must be AA:BB:CC:DD:EE:FF");
        } else if (sendIdentify(mac)) {
            sendAck(seq);
        } else {
            JsonDocument e;
            e["evt"] = "err";
            e["seq"] = seq;
            e["msg"] = "esp_now_send failed";
            sendJson(e);
        }
    }
    else {
        sendError("unknown cmd");
    }
}

void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(100);

    WiFi.mode(WIFI_STA);
    // 11B ist Pflicht: ESP-IDF 5.x lehnt G|N ohne B mit ESP_ERR_INVALID_ARG ab.
    esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
    esp_wifi_set_channel(CCC_CHANNEL, WIFI_SECOND_CHAN_NONE);
    // Maximum (84 = 21 dBm, Einheit 0,25 dBm): keine LEDs, keine Hitze-Grenze wie beim
    // Badge (dort 52 = 13 dBm) → Effekte erreichen auch weit entfernte Badges.
    esp_wifi_set_max_tx_power(84);
    WiFi.setSleep(false);

    if (esp_now_init() != ESP_OK) {
        sendError("esp_now_init failed");
        return;
    }

    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, broadcastMac, 6);
    peer.channel = CCC_CHANNEL;
    peer.encrypt = false;
    esp_now_add_peer(&peer);
    esp_now_register_recv_cb(onDataRecv);

    sendLog("bridge ready");
}

void loop() {
    while (Serial.available()) {
        char c = Serial.read();
        if (c == '\r') {
            continue; // Windows CRLF: skip CR, let LF trigger
        } else if (c == '\n') {
            if (linePos > 0) {
                lineBuf[linePos] = '\0';
                handleCommand(lineBuf);
                linePos = 0;
            }
        } else if (linePos < MAX_JSON_LEN - 1) {
            lineBuf[linePos++] = c;
        } else {
            // Overflow: flush, signal error
            linePos = 0;
            sendError("cmd too long");
        }
    }

    if (pendingActive) {
        bool resend = false;
        portENTER_CRITICAL(&stationMux);
        int aliveCount = countAliveStations();
        int ackedCount = countAckedRound();
        bool allAcked = (aliveCount > 0) && (ackedCount >= aliveCount);

        if (allAcked) {
            pendingActive = false;
        } else if (millis() - pendingSentAt >= ACK_TIMEOUT_MS) {
            if (pendingRetries < MAX_RETRIES && aliveCount > 0) {
                resend = true;
                pendingRetries++;
                pendingSentAt = millis();
            } else {
                pendingActive = false;
            }
        }
        SyncPacket pkt = pendingPkt;
        portEXIT_CRITICAL(&stationMux);
        // esp_now_send nicht im Critical Section aufrufen
        if (resend) {
            esp_now_send(broadcastMac, (uint8_t *)&pkt, sizeof(pkt));
        }
    }

    delay(1);
}
