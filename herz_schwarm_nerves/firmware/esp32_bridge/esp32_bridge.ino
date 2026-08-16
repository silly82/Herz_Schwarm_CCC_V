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
 *   Jede Station, die ein SyncPacket empfängt, sendet per esp_now_send()
 *   ein AckPacket (magic_id, virusID) unicast an die Absender-MAC (=
 *   Bridge) zurück. Die Bridge broadcastet ein SyncPacket bis zu
 *   MAX_RETRIES mal erneut, wenn nicht alle bekannten (kürzlich aktiven)
 *   Stationen innerhalb von ACK_TIMEOUT_MS geantwortet haben. Stationen,
 *   die länger als STATION_STALE_MS nicht geantwortet haben, gelten als
 *   offline und blockieren keine Retries mehr.
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
#define BRIDGE_FW_PATCH 2

#define MAX_JSON_LEN    256
#define SERIAL_BAUD     115200

#define MAX_STATIONS      32     // Obergrenze bekannter Stationen (Swarm hat aktuell 13)
#define ACK_TIMEOUT_MS    150    // Wartezeit auf Acks bevor ggf. erneut gebroadcastet wird
#define MAX_RETRIES       2      // max. Re-Broadcasts pro Effekt (1 initial + 2 Retries)
#define STATION_STALE_MS  30000  // Station gilt nach dieser Inaktivität als offline

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

// Findet eine Station per MAC oder legt sie neu an. Gibt -1 zurueck wenn
// die Tabelle voll ist (Eintrag wird dann stillschweigend verworfen).
static int findOrAddStation(const uint8_t *mac) {
    for (int i = 0; i < knownStationsCount; i++) {
        if (memcmp(knownStations[i].mac, mac, 6) == 0) {
            return i;
        }
    }
    if (knownStationsCount < MAX_STATIONS) {
        memcpy(knownStations[knownStationsCount].mac, mac, 6);
        knownStations[knownStationsCount].ackedRound = false;
        knownStations[knownStationsCount].lastSeenMs = millis();
        return knownStationsCount++;
    }
    return -1;
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

// ESP-NOW-Recv-Callback: Stationen antworten hierueber mit einem AckPacket.
static void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
    if (len != sizeof(AckPacket)) {
        return;
    }

    AckPacket ack;
    memcpy(&ack, data, sizeof(ack));

    if (ack.magic_id != MAGIC_ID || !pendingActive || ack.virusID != pendingPkt.virusID) {
        return;
    }

    int idx = findOrAddStation(info->src_addr);
    if (idx >= 0) {
        knownStations[idx].lastSeenMs = millis();
        knownStations[idx].ackedRound = true;
    }
}

static void sendPong() {
    StaticJsonDocument<128> doc;
    doc["evt"] = "pong";
    doc["peers"] = countAliveStations();
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
            resetAckRound();
            pendingPkt = pkt;
            pendingActive = true;
            pendingSentAt = millis();
            pendingRetries = 0;
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
        int aliveCount = countAliveStations();
        int ackedCount = countAckedRound();
        bool allAcked = (aliveCount > 0) && (ackedCount >= aliveCount);

        if (allAcked) {
            pendingActive = false;
        } else if (millis() - pendingSentAt >= ACK_TIMEOUT_MS) {
            if (pendingRetries < MAX_RETRIES && aliveCount > 0) {
                esp_now_send(broadcastMac, (uint8_t *)&pendingPkt, sizeof(pendingPkt));
                pendingRetries++;
                pendingSentAt = millis();
            } else {
                pendingActive = false;
            }
        }
    }

    delay(1);
}
