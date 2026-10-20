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
 *   {"cmd":"ota_begin","seq":47,"size":1048576,"ver":"0.3.0"}   (UART-OTA, siehe unten)
 *   {"cmd":"ota_chunk","seq":48,"off":0,"data":"<base64, 96 Rohbytes>"}
 *   {"cmd":"ota_end","seq":49}
 *   {"cmd":"ota_abort","seq":50}
 *
 * Protokoll (Bridge → Pi):
 *   {"evt":"ack","seq":42}
 *   {"evt":"pong","peers":5,"uptime":12345,"free_heap":200000,"fw":"0.3.0","ota":"idle"}
 *   {"evt":"peer","mac":"A0:F2:62:EC:3B:B4","rssi":-74,"fw":"1.3.0","age":40}   (je Station)
 *   {"evt":"peers","seq":45,"n":5}                                             (Ende der Liste)
 *   {"evt":"tap","mac":"A0:F2:62:EC:3B:B4","count":123}                    (Tap-Zählerstand eines Badges, nur bei neuem Höchststand)
 *   {"evt":"log","msg":"bridge ready"}
 *   {"evt":"err","msg":"json parse failed"}
 *   {"evt":"err","seq":47,"msg":"busy: ota"}                                  (Fehler mit seq, wo bekannt)
 *
 * UART-OTA (Firmware-Update der Bridge über die bestehende Serial-Verbindung):
 *   ota_begin → Update.begin(size); ota_chunk* (strikt sequenziell, "off" = bisher
 *   geschriebene Rohbytes, ein Chunk darf wiederholt werden); ota_end → Update.end,
 *   Ack, dann Neustart; ota_abort → verwirft. Während des Updates antwortet
 *   "effect" mit err "busy: ota"; status/peers laufen weiter. Eine Zeile darf max.
 *   MAX_JSON_LEN (256) Byte lang sein → Chunks sind OTA_CHUNK_BYTES (96) Rohbytes.
 *   Braucht ein Partition-Schema mit zwei App-Slots (sketch.yaml: min_spiffs).
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
 * Tap-Counter (Badge-FW >= 1.5): Badges senden SyncPackets mit mode = SYNC_MODE_TAP (11)
 *   und virusID = Tap-Zählerstand (monoton, 32 Bit). Von Nachbarn weitergeleitete Pakete
 *   hängen die 6-Byte-MAC des ursprünglichen Badges an (23 Byte), sonst gilt die Absender-MAC.
 *   Die Bridge merkt sich pro MAC den höchsten Stand (Station.taps) und meldet nur höhere
 *   Stände als "tap"-Event; Wiederholungen/Weiterleitungen zählen nie doppelt. Sie leitet nicht weiter.
 *
 * Benötigt: ArduinoJson >= 7 (Library Manager: "ArduinoJson" by Benoit Blanchon)
 */

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <ArduinoJson.h>
#include <Update.h>
#include "mbedtls/base64.h"

#define CCC_CHANNEL     13
#define MAGIC_ID        0x421337CC
#define BRIDGE_FW_MAJOR 0
#define BRIDGE_FW_MINOR 4
#define BRIDGE_FW_PATCH 0  // 0.4.0: Tap-Counter (Modus 11) → UART-Event {"evt":"tap",…}; „Alle stoppen“ (Modus 12, endlose Effekte)

#define MAX_JSON_LEN    256
#define SERIAL_BAUD     115200

#define OTA_CHUNK_BYTES    96      // Rohbytes pro ota_chunk (Base64 = 128 Zeichen, Zeile ~190 Byte < 256)
#define OTA_B64_MAX        136     // max. Base64-Zeichen, die wir akzeptieren (96 Byte → 128, etwas Luft)
#define OTA_IDLE_TIMEOUT_MS 30000  // kein Chunk/Kommando mehr → Update verwerfen, damit "busy" nie hängen bleibt
#define OTA_MAX_BAD_CHUNKS  5      // so viele fehlerhafte Chunks in Folge → Update abbrechen

#define MAX_STATIONS      32     // Obergrenze gleichzeitig bekannter Stationen; veraltete Slots werden wiederverwendet
#define ACK_TIMEOUT_MS    150    // Wartezeit auf Acks bevor ggf. erneut gebroadcastet wird
#define MAX_RETRIES       2      // max. Re-Broadcasts pro Effekt (1 initial + 2 Retries)
#define STATION_STALE_MS  5000   // Station gilt nach dieser Inaktivität als offline (Badges senden mit 20 Hz)
#define SYNC_PACKET_LEGACY_LEN 13
#define SYNC_MODE_IDENTIFY 9     // "Badge finden": SyncPacket + 6 Byte Ziel-MAC (Badge-FW >= 1.3)
#define SYNC_MODE_WAVE_STOP 10   // Welle manuell beenden (Badge-FW, die Modus 4 endlos laufen lässt)
#define SYNC_MODE_TAP      11    // Tap-Counter: virusID = Zählerstand; weitergeleitet + 6 Byte Ursprungs-MAC (Badge-FW >= 1.5)
#define TAP_FWD_PACKET_LEN (sizeof(SyncPacket) + 6)
#define SYNC_MODE_STOP_ALL 12    // „Alle stoppen“: räumt alle Effekte ab (global, virusID 0; Badge-FW >= 1.5). Von der App sendbar, anders als 11
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
    uint32_t taps;       // höchster gesehener Tap-Zählerstand dieser MAC (0 = keiner)
    uint32_t tapsSent;   // davon bereits als UART-Event gemeldet (loop() meldet taps > tapsSent)
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

// UART-OTA-Zustand
enum OtaState : uint8_t { OTA_IDLE, OTA_WRITING, OTA_ERROR };
static OtaState otaState = OTA_IDLE;
static bool     otaActive = false;       // true solange ein Update läuft (nur loop-Task)
static uint32_t otaSize = 0;             // angekündigte Gesamtgröße
static uint32_t otaWritten = 0;          // bisher geschriebene Rohbytes
static uint32_t otaLastOff = 0;          // letzter Chunk, für idempotente Wiederholung (Ack ging verloren)
static uint32_t otaLastLen = 0;
static uint8_t  otaLastData[OTA_CHUNK_BYTES]; // Rohinhalt des letzten Chunks, zum Vergleich bei Wiederholung
static bool     otaLastValid = false;         // true, wenn otaLastData/otaLastLen gültig sind
static uint32_t otaLastActivityMs = 0;   // nur durch gültige Chunks/Wiederholungen aktualisiert
static uint8_t  otaBadChunks = 0;        // fehlerhafte Chunks in Folge
static uint8_t  otaBuf[OTA_CHUNK_BYTES + 8];  // statischer Dekodierpuffer

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

static void sendErrorSeq(uint32_t seq, const char *msg) {
    JsonDocument doc;
    doc["evt"] = "err";
    doc["seq"] = seq;
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
    knownStations[idx].taps = 0;
    knownStations[idx].tapsSent = 0;
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
        // Tap-Pakete tragen den Zählerstand in virusID → nie als Effekt-Ack werten.
        const bool isTap = sp && sp->mode == SYNC_MODE_TAP && len >= (int)sizeof(SyncPacket);
        if (!isTap && pendingActive && virusID == pendingPkt.virusID) {
            knownStations[idx].ackedRound = true;
        }
        if (isTap) {
            // Direkt gehört: Absender = Badge. Weitergeleitet (23 Byte): Ursprungs-MAC im Anhang.
            // Nur Höchststand merken (max) → Wiederholungen/Weiterleitungen zählen nicht doppelt.
            const bool fwd = len >= (int)TAP_FWD_PACKET_LEN;
            int ti = idx;
            if (fwd) {
                const uint8_t *orig = data + sizeof(SyncPacket);
                ti = -1;
                for (int i = 0; i < knownStationsCount; i++) {
                    if (memcmp(knownStations[i].mac, orig, 6) == 0) { ti = i; break; }
                }
                if (ti < 0) {
                    ti = findOrAddStation(orig);
                    // Nur über Dritte gehört: nicht als lebendige Station zeigen (kein RSSI)
                    if (ti >= 0) knownStations[ti].lastSeenMs = millis() - STATION_STALE_MS - 1;
                }
            }
            if (ti >= 0 && sp->virusID > knownStations[ti].taps) {
                knownStations[ti].taps = sp->virusID;
            }
        }
    }
    portEXIT_CRITICAL(&stationMux);
}

// Meldet höchstens ein neues Tap-Event pro Aufruf (loop-Task); Serial nie im WiFi-Callback.
// Mehrere Taps zwischen zwei Aufrufen verschmelzen zum aktuellen Höchststand.
static void emitTapEvent() {
    uint8_t mac[6];
    uint32_t count = 0;
    portENTER_CRITICAL(&stationMux);
    for (int i = 0; i < knownStationsCount; i++) {
        if (knownStations[i].taps > knownStations[i].tapsSent) {
            memcpy(mac, knownStations[i].mac, 6);
            count = knownStations[i].taps;
            knownStations[i].tapsSent = count;
            break;
        }
    }
    portEXIT_CRITICAL(&stationMux);
    if (count == 0) return;
    char macStr[18];
    snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    JsonDocument doc;
    doc["evt"] = "tap";
    doc["mac"] = macStr;
    doc["count"] = count;
    sendJson(doc);
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
    char fw[12];
    snprintf(fw, sizeof(fw), "%d.%d.%d", BRIDGE_FW_MAJOR, BRIDGE_FW_MINOR, BRIDGE_FW_PATCH);
    doc["fw"] = fw;
    doc["ota"] = otaState == OTA_WRITING ? "writing" : (otaState == OTA_ERROR ? "error" : "idle");
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

// --- UART-OTA ---

// Update abbrechen und aufräumen. failed=true → Zustand "error" (in pong sichtbar).
static void otaReset(bool failed) {
    if (otaActive) {
        Update.abort();
    }
    otaActive = false;
    otaSize = 0;
    otaWritten = 0;
    otaLastOff = 0;
    otaLastLen = 0;
    otaLastValid = false;
    otaBadChunks = 0;
    otaState = failed ? OTA_ERROR : OTA_IDLE;
}

static void handleOtaBegin(JsonDocument &doc, uint32_t seq) {
    if (otaActive) {
        sendErrorSeq(seq, "busy: ota");
        return;
    }
    uint32_t size = doc["size"] | (uint32_t)0;
    if (size == 0) {
        sendErrorSeq(seq, "size required");
        return;
    }
    // Eine laufende Effekt-Zustellung ist hier unwichtig; Update.begin löscht den
    // Ziel-Slot (kann 1-3 s dauern, die App wartet dafür länger auf dieses Ack).
    if (!Update.begin(size, U_FLASH)) {
        otaState = OTA_ERROR;
        sendErrorSeq(seq, Update.errorString());
        Update.abort();
        return;
    }
    otaActive = true;
    otaState = OTA_WRITING;
    otaSize = size;
    otaWritten = 0;
    otaLastOff = 0;
    otaLastLen = 0;
    otaLastValid = false;
    otaBadChunks = 0;
    otaLastActivityMs = millis();
    sendAck(seq);
}

// Fehlerhaften Chunk melden. Der Idle-Timer wird dabei bewusst NICHT verlängert,
// damit ein Update mit nur kaputten Chunks per Idle-Timeout endet.
static void otaRejectChunk(uint32_t seq, const char *msg) {
    sendErrorSeq(seq, msg);
    if (++otaBadChunks >= OTA_MAX_BAD_CHUNKS) {
        otaReset(true);
        sendLog("ota: zu viele fehlerhafte Chunks, abgebrochen");
    }
}

static void handleOtaChunk(JsonDocument &doc, uint32_t seq) {
    if (!otaActive) {
        sendErrorSeq(seq, "no ota in progress");
        return;
    }
    uint32_t off = doc["off"] | (uint32_t)0;
    const char *b64 = doc["data"] | "";
    size_t b64Len = strlen(b64);
    if (b64Len == 0 || b64Len > OTA_B64_MAX) {
        otaRejectChunk(seq, "bad chunk size");
        return;
    }
    size_t len = 0;
    if (mbedtls_base64_decode(otaBuf, sizeof(otaBuf), &len, (const unsigned char *)b64, b64Len) != 0 || len == 0) {
        otaRejectChunk(seq, "bad base64");
        return;
    }
    // Wiederholung des zuletzt geschriebenen Chunks (Ack ging unterwegs verloren): nur erneut bestätigen,
    // aber nur wenn der Inhalt identisch ist. Abweichender Inhalt ist ein Fehler und verlängert nichts.
    if (otaWritten > 0 && otaLastValid && off == otaLastOff && len == otaLastLen) {
        if (memcmp(otaBuf, otaLastData, len) != 0) {
            otaRejectChunk(seq, "chunk content mismatch");
            return;
        }
        otaLastActivityMs = millis();
        otaBadChunks = 0;
        sendAck(seq);
        return;
    }
    if (off != otaWritten) {
        otaRejectChunk(seq, "offset mismatch");
        return;
    }
    if (otaWritten + len > otaSize) {
        otaRejectChunk(seq, "chunk exceeds size");
        return;
    }
    size_t w = Update.write(otaBuf, len);
    if (w != len) {
        // errorString vor abort() lesen: abort() setzt den Fehler zurück
        sendErrorSeq(seq, Update.errorString());
        otaReset(true);
        return;
    }
    otaLastOff = otaWritten;
    otaLastLen = (uint32_t)len;
    // Rohinhalt merken (nur wenn er in den Vergleichspuffer passt; sonst keine Wiederholungserkennung für diesen Chunk)
    otaLastValid = len <= OTA_CHUNK_BYTES;
    if (otaLastValid) {
        memcpy(otaLastData, otaBuf, len);
    }
    otaWritten += (uint32_t)len;
    otaLastActivityMs = millis();
    otaBadChunks = 0;
    sendAck(seq);
}

static void handleOtaEnd(uint32_t seq) {
    if (!otaActive) {
        sendErrorSeq(seq, "no ota in progress");
        return;
    }
    if (otaWritten != otaSize) {
        // Update bleibt offen: die App kann abbrechen oder (nach Fehler) neu starten.
        sendErrorSeq(seq, "incomplete");
        return;
    }
    if (!Update.end(true)) {
        sendErrorSeq(seq, Update.errorString());
        otaReset(true);
        return;
    }
    otaActive = false;
    otaState = OTA_IDLE;
    sendAck(seq);
    Serial.flush();
    delay(500);
    ESP.restart();
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
        if (otaActive) {
            sendErrorSeq(seq, "busy: ota");
            return;
        }
        uint8_t mode = doc["mode"] | 0;
        // Stopp: ID der laufenden Welle aus dem JSON, sonst 0 (Wildcard), nie Zufalls-ID.
        // „Alle stoppen“ ist global: virusID immer 0.
        uint32_t virusID = (mode == SYNC_MODE_STOP_ALL)
                               ? (uint32_t)0
                           : (mode == SYNC_MODE_WAVE_STOP)
                               ? (doc["virusID"] | (uint32_t)0)
                               : (doc["virusID"] | (uint32_t)esp_random());
        uint32_t beatCounter = doc["beatCounter"] | (uint32_t)millis();

        // 9 (Identify) und 11 (Tap, reiner Empfangsmodus) sind über "effect" nicht sendbar
        if ((mode < 1 || mode > 8) && mode != SYNC_MODE_WAVE_STOP && mode != SYNC_MODE_STOP_ALL) {
            sendError("mode must be 1-8, 10 or 12");
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
    else if (strcmp(cmd, "ota_begin") == 0) {
        handleOtaBegin(doc, seq);
    }
    else if (strcmp(cmd, "ota_chunk") == 0) {
        handleOtaChunk(doc, seq);
    }
    else if (strcmp(cmd, "ota_end") == 0) {
        handleOtaEnd(seq);
    }
    else if (strcmp(cmd, "ota_abort") == 0) {
        otaReset(false);
        sendAck(seq);
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

    emitTapEvent();

    // Verwaistes Update (App weg, Kabel gezogen) nach Timeout verwerfen
    if (otaActive && millis() - otaLastActivityMs > OTA_IDLE_TIMEOUT_MS) {
        otaReset(true);
        sendLog("ota timeout, aborted");
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
