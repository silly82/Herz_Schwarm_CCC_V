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
 *
 * Protokoll (Bridge → Pi):
 *   {"evt":"ack","seq":42}
 *   {"evt":"pong","peers":5,"uptime":12345}
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
 * Benötigt: ArduinoJson Library (Library Manager: "ArduinoJson" by Benoit Blanchon)
 */

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <ArduinoJson.h>

#define CCC_CHANNEL     13
#define MAGIC_ID        0x421337CC
#define BRIDGE_FW_MAJOR 0
#define BRIDGE_FW_MINOR 1
#define BRIDGE_FW_PATCH 3

#define MAX_JSON_LEN    256
#define SERIAL_BAUD     115200

#define MAX_STATIONS      32     // Obergrenze gleichzeitig bekannter Stationen; veraltete Slots werden wiederverwendet
#define ACK_TIMEOUT_MS    150    // Wartezeit auf Acks bevor ggf. erneut gebroadcastet wird
#define MAX_RETRIES       2      // max. Re-Broadcasts pro Effekt (1 initial + 2 Retries)
#define STATION_STALE_MS  5000   // Station gilt nach dieser Inaktivität als offline (Badges senden mit 20 Hz)
#define SYNC_PACKET_LEGACY_LEN 13

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
    StaticJsonDocument<64> doc;
    doc["evt"] = "ack";
    doc["seq"] = seq;
    sendJson(doc);
}

static void sendError(const char *msg) {
    StaticJsonDocument<128> doc;
    doc["evt"] = "err";
    doc["msg"] = msg;
    sendJson(doc);
}

static void sendLog(const char *msg) {
    StaticJsonDocument<128> doc;
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
    if (len == sizeof(AckPacket)) {
        virusID = ((const AckPacket *)data)->virusID;
    } else if (len >= SYNC_PACKET_LEGACY_LEN) {
        virusID = ((const SyncPacket *)data)->virusID;
    } else {
        return;
    }

    portENTER_CRITICAL(&stationMux);
    int idx = findOrAddStation(info->src_addr);
    if (idx >= 0) {
        knownStations[idx].lastSeenMs = millis();
        if (pendingActive && virusID == pendingPkt.virusID) {
            knownStations[idx].ackedRound = true;
        }
    }
    portEXIT_CRITICAL(&stationMux);
}

static void sendPong() {
    StaticJsonDocument<128> doc;
    doc["evt"] = "pong";
    portENTER_CRITICAL(&stationMux);
    int alive = countAliveStations();
    portEXIT_CRITICAL(&stationMux);
    doc["peers"] = alive;
    doc["uptime"] = (uint32_t)(millis() / 1000);
    doc["free_heap"] = ESP.getFreeHeap();
    sendJson(doc);
}

static void handleCommand(const char *json) {
    StaticJsonDocument<256> doc;
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
            StaticJsonDocument<128> e;
            e["evt"] = "err";
            e["seq"] = seq;
            e["msg"] = "esp_now_send failed";
            sendJson(e);
        }
    }
    else if (strcmp(cmd, "status") == 0) {
        sendPong();
    }
    else {
        sendError("unknown cmd");
    }
}

void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(100);

    WiFi.mode(WIFI_STA);
    esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
    esp_wifi_set_channel(CCC_CHANNEL, WIFI_SECOND_CHAN_NONE);
    esp_wifi_set_max_tx_power(52);
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
        } else if (c == '\n' || c == '\r') {
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
