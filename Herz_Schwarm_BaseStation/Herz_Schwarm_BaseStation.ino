/**
 * Herz-Schwarm Basisstation (ESP32-S3 + W5500 Ethernet, z. B. Spotpear ESP32-S3-ETH)
 *
 * - Lauscht ESP-NOW auf Kanal 13 (kompatibel zu Herz_Schwarm_CCC_V Badges).
 * - Keine regelmäßigen Sends → erscheint nicht in der Peer-Zählung der Badges.
 * - Optional: Effekt-Broadcast (SyncPacket mode 1–8, siehe README "mode-Werte").
 * - Web-UI + JSON-API unter http://herz-base.local (mDNS); MQTT optional,
 *   Broker/Zugangsdaten/Topics per Web-UI (NVS).
 * - "Badge finden" (Modus 9, Ziel-MAC) und OTA-Update per Web-UI (Passwort, s. u.).
 *
 * Pinbelegung W5500 laut Spotpear-Wiki: SCK 13, MISO 12, MOSI 11, CS 14, RST 9, INT 10
 */

#include <Arduino.h>
#include <WiFi.h>
#include <Network.h>
#include <Preferences.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <ETH.h>
#include <SPI.h>
#include <WebServer.h>
#include <NetworkClient.h>
#include <PubSubClient.h>
#include <ESPmDNS.h>
#include <Update.h>

// OTA-Passwort ist fest einkompiliert. Das Repo ist öffentlich und enthält nur den
// Platzhalter; das echte Passwort in ota_secret.h (gitignored, Vorlage:
// ota_secret.h.example) definieren:  #define OTA_PASSWORD "..."
#if __has_include("ota_secret.h")
#include "ota_secret.h"
#endif
#ifndef OTA_PASSWORD
#define OTA_PASSWORD "herzschwarm"
#define OTA_PASSWORD_IS_DEFAULT 1
#else
#define OTA_PASSWORD_IS_DEFAULT 0
#endif
#define OTA_USER "admin"

// --- Konfiguration Ethernet (Spotpear ESP32-S3-ETH) ---
#define ETH_PHY_TYPE   ETH_PHY_W5500
#define ETH_PHY_ADDR   1
#define ETH_PHY_CS     14
#define ETH_PHY_IRQ    10
#define ETH_PHY_RST    9
#define ETH_SPI_SCK    13
#define ETH_SPI_MISO   12
#define ETH_SPI_MOSI   11

// --- Schwarm (muss zum Badge-Sketch passen) ---
#define CCC_CHANNEL          13
#define MAGIC_ID             0x421337CC
#define PEER_TIMEOUT_MS      4000
#define MAX_PEERS            32
#define SYNC_PACKET_LEGACY_LEN 13
#define SYNC_MODE_MAX        8   // Badge-FW kennt Modi 1..8
#define SYNC_MODE_AMBIENT    7   // Farbe als 0xRRGGBB im beatCounter
#define SYNC_MODE_IDENTIFY   9   // "Badge finden": SyncPacket + 6 Byte Ziel-MAC
#define SYNC_MODE_WAVE_STOP  10  // Welle manuell stoppen; ausserhalb von SYNC_MODE_MAX (Sonderfall)
#define IDENTIFY_REPEATS     3   // Funk ist verlustbehaftet; Badge dedupliziert per virusID
#define WAVE_STOP_REPEATS    3   // Stopp-Broadcast mehrfach senden (wie Identify)
#define WAVE_STOP_GAP_MS     60
#define HOSTNAME             "herz-base"

#define BASESTATION_FW_MAJOR 0
#define BASESTATION_FW_MINOR     3
#define BASESTATION_FW_PATCH     1

#define MQTT_NS "hs_mqtt"
#define MQTT_HOST_DEF    "192.168.1.10"
#define MQTT_TOPIC_STATUS_DEF "herzschwarm/base/status"
#define MQTT_TOPIC_CMD_DEF    "herzschwarm/base/cmd/virus"
#define MQTT_STATUS_JSON_LEN  2048
// PubSubClient-Puffer muss Header + Topic + Payload fassen
#define MQTT_BUFFER_LEN       (MQTT_STATUS_JSON_LEN + sizeof(((MqttCfg *)0)->topicStatus) + 8)

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

struct PeerEntry {
    uint8_t mac[6];
    uint32_t lastSeen;
    int8_t   rssi;
    uint8_t  ver_major;
    uint8_t  ver_minor;
    uint8_t  ver_rel;
    uint8_t  ver_dbg;
    uint8_t  ver_known;
    uint8_t  in_use;
};

static PeerEntry peers[MAX_PEERS];
static portMUX_TYPE peerMux = portMUX_INITIALIZER_UNLOCKED;

static uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

static volatile bool ethGotIp = false;
static WebServer server(80);

struct MqttCfg {
    bool enabled;
    char host[96];
    uint16_t port;
    char user[48];
    char pass[64];
    char topicStatus[80];
    char topicCmd[80];
};

static MqttCfg mqttCfg;
static Preferences mqttPrefs;
static NetworkClient mqttNet;
static PubSubClient mqtt(mqttNet);
static uint32_t lastMqttPublish = 0;

// Welle läuft (mode 4 gesendet, noch kein Stopp) — nur für den Web-UI-Toggle
static bool waveRunning = false;
static uint32_t lastWaveId = 0;  // ID der zuletzt gestarteten Welle (Ziel-ID im Stopp-Paket); bleibt nach Stopp erhalten
// ID der zuletzt gestoppten Welle: weitergeleitete Pakete dieser ID setzen waveRunning nicht wieder.
// Nur Vergleich über ID-Gleichheit, wird beim Start nicht gelöscht.
static uint32_t waveStopId = 0;

static void sendEffectBroadcast(uint8_t mode, uint32_t beatCounter);
static bool sendIdentify(const uint8_t *mac);
static void loadMqttConfig();
static bool resolveMqttBroker(IPAddress &out);
static void mqttCallback(char *topic, byte *payload, unsigned int len);
static void appendJsonString(char *buf, size_t cap, size_t *off, const char *s);

// WiFi/ESP-NOW wie Badge-Sketch; nach ETH-Start erneut aufrufen (Stack kann Kanal zurücksetzen).
static void applyEspNowRadio() {
    WiFi.mode(WIFI_STA);
    // 11B ist Pflicht: ESP-IDF 5.x lehnt G|N ohne B mit ESP_ERR_INVALID_ARG ab.
    if (esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N) != ESP_OK) {
        Serial.println("esp_wifi_set_protocol fehlgeschlagen");
    }
    esp_err_t err = esp_wifi_set_channel(CCC_CHANNEL, WIFI_SECOND_CHAN_NONE);
    if (err != ESP_OK) {
        Serial.printf("esp_wifi_set_channel fehlgeschlagen: %d\n", (int)err);
    }
    // Maximum (84 = 21 dBm, Einheit 0,25 dBm): keine LEDs, keine Hitze-Grenze wie beim
    // Badge (dort 52 = 13 dBm) → Effekte erreichen auch weit entfernte Badges.
    esp_wifi_set_max_tx_power(84);
    WiFi.setSleep(false);
    esp_wifi_set_ps(WIFI_PS_NONE);
    uint8_t prim = 0;
    wifi_second_chan_t sec = WIFI_SECOND_CHAN_NONE;
    if (esp_wifi_get_channel(&prim, &sec) == ESP_OK) {
        Serial.printf("ESP-NOW: feste Funk-Kanalnummer %u (Ziel %d)\n", (unsigned)prim, CCC_CHANNEL);
    }
}

static void onNetworkEvent(arduino_event_id_t event, arduino_event_info_t info) {
    (void)info;
    switch (event) {
        case ARDUINO_EVENT_ETH_START:
            ETH.setHostname(HOSTNAME);
            break;
        case ARDUINO_EVENT_ETH_GOT_IP:
            ethGotIp = true;
            Serial.print("ETH IP: ");
            Serial.println(ETH);
            MDNS.end();
            if (MDNS.begin(HOSTNAME)) {
                MDNS.addService("http", "tcp", 80);
                Serial.println("mDNS: http://" HOSTNAME ".local");
            }
            // Erst NACH MDNS.begin(): mDNS verstellt den WiFi-Stack, ohne
            // erneutes Festlegen von Kanal 13 kommen keine ESP-NOW-Pakete mehr an.
            applyEspNowRadio();
            break;
        case ARDUINO_EVENT_ETH_LOST_IP:
        case ARDUINO_EVENT_ETH_DISCONNECTED:
        case ARDUINO_EVENT_ETH_STOP:
            ethGotIp = false;
            break;
        default:
            break;
    }
}

// Kopiert die aktiven Peers unter peerMux nach out[] und liefert ihre Anzahl.
// Formatiert wird danach ohne Sperre (snprintf mit gesperrten Interrupts vermeiden).
// *nowOut wird unter der Sperre gelesen, damit kein lastSeen "in der Zukunft" liegt.
static int snapshotActivePeers(PeerEntry *out, uint32_t *nowOut) {
    int n = 0;
    portENTER_CRITICAL(&peerMux);
    uint32_t now = millis();
    for (int i = 0; i < MAX_PEERS; i++) {
        if (peers[i].in_use && (now - peers[i].lastSeen) <= PEER_TIMEOUT_MS) out[n++] = peers[i];
    }
    portEXIT_CRITICAL(&peerMux);
    *nowOut = now;
    return n;
}

static void updatePeer(const uint8_t *mac, int8_t rssi, bool hasVer,
                       uint8_t vmaj, uint8_t vmin, uint8_t vrel, uint8_t vdbg) {
    uint32_t now = millis();
    portENTER_CRITICAL(&peerMux);
    for (int i = 0; i < MAX_PEERS; i++) {
        if (peers[i].in_use && memcmp(peers[i].mac, mac, 6) == 0) {
            peers[i].lastSeen = now;
            peers[i].rssi = rssi;
            if (hasVer) {
                peers[i].ver_major = vmaj;
                peers[i].ver_minor = vmin;
                peers[i].ver_rel = vrel;
                peers[i].ver_dbg = vdbg;
                peers[i].ver_known = 1;
            }
            portEXIT_CRITICAL(&peerMux);
            return;
        }
    }
    for (int i = 0; i < MAX_PEERS; i++) {
        if (!peers[i].in_use) {
            memcpy(peers[i].mac, mac, 6);
            peers[i].lastSeen = now;
            peers[i].rssi = rssi;
            peers[i].ver_known = hasVer ? 1 : 0;
            if (hasVer) {
                peers[i].ver_major = vmaj;
                peers[i].ver_minor = vmin;
                peers[i].ver_rel = vrel;
                peers[i].ver_dbg = vdbg;
            }
            peers[i].in_use = 1;
            portEXIT_CRITICAL(&peerMux);
            return;
        }
    }
    portEXIT_CRITICAL(&peerMux);
}

static void purgeStalePeers() {
    portENTER_CRITICAL(&peerMux);
    uint32_t now = millis();  // unter der Sperre: OnDataRecv kann lastSeen sonst "nach" now setzen
    for (int i = 0; i < MAX_PEERS; i++) {
        if (peers[i].in_use && (now - peers[i].lastSeen) > PEER_TIMEOUT_MS) {
            peers[i].in_use = 0;
        }
    }
    portEXIT_CRITICAL(&peerMux);
}

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
    if (len < SYNC_PACKET_LEGACY_LEN) return;
    if (*(const uint32_t *)data != MAGIC_ID) return;

    SyncPacket rx;
    memset(&rx, 0, sizeof(rx));
    memcpy(&rx, data, (size_t)len < sizeof(rx) ? (size_t)len : sizeof(rx));
    const bool hasVer = (len >= (int)sizeof(SyncPacket));

    int8_t rssi = recv_info->rx_ctrl->rssi;
    updatePeer(recv_info->src_addr, rssi, hasVer, rx.ver_major, rx.ver_minor, rx.ver_rel, rx.ver_dbg);

    // Wellenzustand aus weitergeleiteten Badge-Paketen lernen (auch für Wellen aus Nerves)
    if (rx.mode == 4 && rx.virusID != waveStopId) {  // 4 = Welle
        waveRunning = true;
        lastWaveId = rx.virusID;
    } else if (rx.mode == SYNC_MODE_WAVE_STOP) {
        waveRunning = false;
        waveStopId = (rx.virusID != 0) ? rx.virusID : lastWaveId;
    }
}

static void appendMac(char *buf, size_t buflen, size_t *off, const uint8_t *mac) {
    *off += snprintf(buf + *off, buflen - *off, "%02X:%02X:%02X:%02X:%02X:%02X",
                     mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static void handleVirus() {
    sendEffectBroadcast(1, millis());
    server.send(200, "text/plain", "ok");
}

// Farbe "RRGGBB" oder "#RRGGBB" → 0xRRGGBB; ungültig → Weiß
static uint32_t parseHexColor(const char *s) {
    if (*s == '#') s++;
    char *end = nullptr;
    unsigned long v = strtoul(s, &end, 16);
    if (end == s || (end - s) != 6) return 0xFFFFFF;
    return (uint32_t)v;
}

// POST /api/effect?m=1..8|10[&c=RRGGBB]  (c nur für m=7 Ambient, m=10 = Welle stoppen)
static void handleEffect() {
    long m = server.arg("m").toInt();
    if ((m < 1 || m > SYNC_MODE_MAX) && m != SYNC_MODE_WAVE_STOP) {
        server.send(400, "text/plain", "m muss 1-8 oder 10 sein");
        return;
    }
    uint32_t beat = (m == SYNC_MODE_AMBIENT) ? parseHexColor(server.arg("c").c_str()) : millis();
    sendEffectBroadcast((uint8_t)m, beat);
    server.send(200, "text/plain", "ok");
}

static void appendJsonString(char *buf, size_t cap, size_t *off, const char *s) {
    if (*off >= cap - 4) return;
    buf[(*off)++] = '"';
    for (; *s && *off < cap - 3; s++) {
        unsigned char c = (unsigned char)*s;
        if (c == '"' || c == '\\') {
            buf[(*off)++] = '\\';
            buf[(*off)++] = (char)c;
        } else if (c >= 32 && c != 127) {
            buf[(*off)++] = (char)c;
        }
    }
    buf[(*off)++] = '"';
    buf[*off] = '\0';
}

static void loadMqttConfig() {
    mqttPrefs.begin(MQTT_NS, true);
    mqttCfg.enabled = mqttPrefs.getBool("en", false);
    mqttPrefs.getString("host", mqttCfg.host, sizeof(mqttCfg.host));
    if (mqttCfg.host[0] == '\0') {
        strncpy(mqttCfg.host, MQTT_HOST_DEF, sizeof(mqttCfg.host) - 1);
        mqttCfg.host[sizeof(mqttCfg.host) - 1] = '\0';
    }
    mqttCfg.port = (uint16_t)mqttPrefs.getUInt("port", 1883);
    if (mqttCfg.port == 0) mqttCfg.port = 1883;
    mqttPrefs.getString("user", mqttCfg.user, sizeof(mqttCfg.user));
    mqttPrefs.getString("pass", mqttCfg.pass, sizeof(mqttCfg.pass));
    mqttPrefs.getString("ts", mqttCfg.topicStatus, sizeof(mqttCfg.topicStatus));
    if (mqttCfg.topicStatus[0] == '\0') {
        strncpy(mqttCfg.topicStatus, MQTT_TOPIC_STATUS_DEF, sizeof(mqttCfg.topicStatus) - 1);
    }
    mqttPrefs.getString("tc", mqttCfg.topicCmd, sizeof(mqttCfg.topicCmd));
    if (mqttCfg.topicCmd[0] == '\0') {
        strncpy(mqttCfg.topicCmd, MQTT_TOPIC_CMD_DEF, sizeof(mqttCfg.topicCmd) - 1);
    }
    mqttPrefs.end();
}

static bool resolveMqttBroker(IPAddress &out) {
    return Network.hostByName(mqttCfg.host, out) == 1;
}

static void mqttBuildClientId(char *cid, size_t clen) {
    uint8_t m[6] = {};
    ETH.macAddress(m);
    snprintf(cid, clen, "herzsw-%02X%02X%02X", m[3], m[4], m[5]);
}

// Payload: leer → Virus (kompatibel zu früher); "N" → Modus N (1..8);
// "10" → Welle stoppen; "7:RRGGBB" → Ambient-Farbe.
static void mqttCallback(char *topic, byte *payload, unsigned int len) {
    if (strcmp(topic, mqttCfg.topicCmd) != 0) return;
    char buf[16];
    unsigned int n = len < sizeof(buf) - 1 ? len : sizeof(buf) - 1;
    memcpy(buf, payload, n);
    buf[n] = '\0';
    long m = n ? strtol(buf, nullptr, 10) : 1;
    if ((m < 1 || m > SYNC_MODE_MAX) && m != SYNC_MODE_WAVE_STOP) {
        Serial.printf("MQTT cmd ignoriert: \"%s\"\n", buf);
        return;
    }
    uint32_t beat = millis();
    if (m == SYNC_MODE_AMBIENT) {
        const char *colon = strchr(buf, ':');
        beat = colon ? parseHexColor(colon + 1) : 0xFFFFFF;
    }
    sendEffectBroadcast((uint8_t)m, beat);
}

static void mqttTryConnect() {
    if (!mqttCfg.enabled) {
        if (mqtt.connected()) mqtt.disconnect();
        return;
    }
    static uint32_t lastTry = 0;
    if (!ethGotIp || mqtt.connected()) return;
    uint32_t t = millis();
    if (t - lastTry < 3000) return;
    lastTry = t;

    IPAddress ip;
    if (!resolveMqttBroker(ip)) {
        Serial.printf("MQTT: DNS/Auflösung fehlgeschlagen: %s\n", mqttCfg.host);
        return;
    }
    mqtt.setServer(ip, mqttCfg.port);

    char clientId[24];
    mqttBuildClientId(clientId, sizeof(clientId));

    bool ok;
    if (mqttCfg.user[0] != '\0') {
        ok = mqtt.connect(clientId, mqttCfg.user, mqttCfg.pass);
    } else {
        ok = mqtt.connect(clientId);
    }
    if (ok) {
        mqtt.subscribe(mqttCfg.topicCmd);
        Serial.println("MQTT verbunden");
    } else {
        Serial.printf("MQTT Verbindung fehlgeschlagen rc=%d\n", mqtt.state());
    }
}

static void mqttPublishStatus() {
    if (!mqtt.connected()) return;
    static PeerEntry snap[MAX_PEERS];
    uint32_t now;
    int n = snapshotActivePeers(snap, &now);
    char json[MQTT_STATUS_JSON_LEN];
    size_t o = 0;
    o += snprintf(json + o, sizeof(json) - o, "{\"n\":%d,\"peers\":[", n);
    for (int i = 0; i < n; i++) {
        if (i) o += snprintf(json + o, sizeof(json) - o, ",");
        o += snprintf(json + o, sizeof(json) - o, "{\"mac\":\"");
        appendMac(json, sizeof(json), &o, snap[i].mac);
        o += snprintf(json + o, sizeof(json) - o, "\",\"rssi\":%d}", snap[i].rssi);
        if (o >= sizeof(json) - 32) break;
    }
    o += snprintf(json + o, sizeof(json) - o, "]}");
    if (!mqtt.publish(mqttCfg.topicStatus, json)) {
        Serial.printf("MQTT publish fehlgeschlagen (%u Byte)\n", (unsigned)o);
    }
}

static void handleMqttGet() {
    char json[768];
    size_t o = 0;
    o += snprintf(json + o, sizeof(json) - o, "{\"enabled\":%s,\"host\":",
 mqttCfg.enabled ? "true" : "false");
    appendJsonString(json, sizeof(json), &o, mqttCfg.host);
    o += snprintf(json + o, sizeof(json) - o, ",\"port\":%u,\"user\":", (unsigned)mqttCfg.port);
    appendJsonString(json, sizeof(json), &o, mqttCfg.user);
    o += snprintf(json + o, sizeof(json) - o, ",\"has_password\":%s,\"topic_status\":",
                  mqttCfg.pass[0] ? "true" : "false");
    appendJsonString(json, sizeof(json), &o, mqttCfg.topicStatus);
    o += snprintf(json + o, sizeof(json) - o, ",\"topic_cmd\":");
    appendJsonString(json, sizeof(json), &o, mqttCfg.topicCmd);
    o += snprintf(json + o, sizeof(json) - o, ",\"connected\":%s}",
                  (mqttCfg.enabled && mqtt.connected()) ? "true" : "false");
    server.send(200, "application/json", json);
}

static void handleMqttPost() {
    if (server.method() != HTTP_POST) {
        server.send(405, "text/plain", "method");
        return;
    }
    mqttPrefs.begin(MQTT_NS, false);
    mqttPrefs.putBool("en", server.hasArg("en") && (server.arg("en") == "1" || server.arg("en") == "true"));

    if (server.hasArg("host")) {
        String h = server.arg("host");
        h.trim();
        mqttPrefs.putString("host", h.length() ? h : String(MQTT_HOST_DEF));
    }
    if (server.hasArg("port")) {
        long p = server.arg("port").toInt();
        if (p >= 1 && p <= 65535) mqttPrefs.putUInt("port", (uint32_t)p);
    }
    if (server.hasArg("user")) {
        mqttPrefs.putString("user", server.arg("user"));
    }
    if (server.hasArg("pass") && server.arg("pass").length() > 0) {
        mqttPrefs.putString("pass", server.arg("pass"));
    }
    if (server.hasArg("ts")) {
        String ts = server.arg("ts");
        ts.trim();
        if (ts.length()) mqttPrefs.putString("ts", ts);
    }
    if (server.hasArg("tc")) {
        String tc = server.arg("tc");
        tc.trim();
        if (tc.length()) mqttPrefs.putString("tc", tc);
    }
    mqttPrefs.end();

    loadMqttConfig();
    mqtt.disconnect();
    lastMqttPublish = 0;
    server.send(200, "application/json", "{\"ok\":true}");
}

static void handleRoot() {
    static const char page[] PROGMEM = R"HTML(
<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Herz-Schwarm Basisstation</title>
<style>
:root{--bg:#0f0f12;--card:#1a1a22;--bd:#2d2d3a;--txt:#e8e6f0;--muted:#8b8798;--pink:#ff4d8a;--cyan:#00d4aa;--warn:#ffc14d;}
*{box-sizing:border-box}body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--txt);margin:0;min-height:100vh;
  background-image:radial-gradient(ellipse 120% 80% at 50% -20%,#2a1530 0%,transparent 55%);}
.wrap{max-width:920px;margin:0 auto;padding:1.25rem 1rem 3rem;}
header{display:flex;flex-wrap:wrap;align-items:center;gap:.75rem 1.25rem;margin-bottom:1.25rem;}
h1{font-size:1.45rem;font-weight:700;margin:0;letter-spacing:-.02em;}
.badge{display:inline-flex;align-items:center;gap:.35rem;background:var(--card);border:1px solid var(--bd);padding:.35rem .7rem;border-radius:999px;font-size:.82rem;color:var(--muted);}
.badge strong{color:var(--cyan);font-weight:600}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.75rem;margin-bottom:1.25rem;}
.stat{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:1rem;text-align:center;}
.stat .big{font-size:1.75rem;font-weight:800;color:var(--pink);line-height:1.2;}
.stat .lbl{font-size:.78rem;color:var(--muted);margin-top:.25rem;text-transform:uppercase;letter-spacing:.06em;}
.card{background:var(--card);border:1px solid var(--bd);border-radius:14px;padding:1rem 1.1rem;margin-bottom:1rem;overflow:hidden;}
.card h2{font-size:.95rem;margin:0 0 .75rem;color:var(--muted);font-weight:600;display:flex;align-items:center;gap:.45rem;}
.btn{cursor:pointer;border:none;border-radius:10px;padding:.65rem 1.1rem;font-size:.95rem;font-weight:600;color:#fff;
  background:linear-gradient(135deg,var(--pink),#b03070);box-shadow:0 4px 18px rgba(255,77,138,.35);transition:transform .12s,filter .12s;}
.btn:hover{filter:brightness(1.08);transform:translateY(-1px)}.btn:active{transform:translateY(0)}
.btn-row{display:flex;flex-wrap:wrap;gap:.5rem;margin-top:.35rem}
.btn-rb{background:linear-gradient(135deg,#6c5ce7,#a855f7);box-shadow:0 4px 18px rgba(108,92,231,.35)}
.btn-pr{background:linear-gradient(135deg,var(--cyan),#0d9488);box-shadow:0 4px 18px rgba(0,212,170,.3)}
.btn-wv{background:linear-gradient(135deg,#3b82f6,#6366f1);box-shadow:0 4px 18px rgba(59,130,246,.35)}
.btn-sec{background:linear-gradient(135deg,#3d3d52,#52526b);box-shadow:0 2px 12px rgba(0,0,0,.25)}
.btn-bt{background:linear-gradient(135deg,#f97316,#ea580c);box-shadow:0 4px 18px rgba(249,115,22,.3)}
.btn-zn{background:linear-gradient(135deg,#eab308,#ca8a04);box-shadow:0 4px 18px rgba(234,179,8,.3)}
.btn-st{background:linear-gradient(135deg,#64748b,#334155);box-shadow:0 4px 18px rgba(100,116,139,.3)}
.amb{display:inline-flex;align-items:center;gap:.35rem}
.amb input[type=color]{width:2.6rem;height:2.4rem;border:1px solid var(--bd);border-radius:8px;background:#12121a;padding:2px;cursor:pointer}
.warn{font-size:.78rem;color:var(--warn);margin:.6rem 0 0}
.btn-find{padding:.35rem .7rem;font-size:.8rem;background:linear-gradient(135deg,#22c55e,#15803d);box-shadow:0 2px 10px rgba(34,197,94,.3)}
#msg,#mqmsg,#otamsg{min-height:1.4rem;font-size:.88rem;color:var(--cyan);margin:.5rem 0 0;}
.form-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:.85rem;margin:.5rem 0 1rem;}
.form-grid label{display:flex;flex-direction:column;gap:.35rem;font-size:.78rem;color:var(--muted)}
.inp,.form-grid input[type=text],.form-grid input[type=password],.form-grid input[type=number]{
  background:#12121a;border:1px solid var(--bd);border-radius:8px;padding:.5rem .65rem;color:var(--txt);font-size:.9rem;}
.chk-row{display:flex;align-items:center;gap:.5rem;margin:.35rem 0 .75rem;font-size:.88rem;color:var(--txt)}
.chk-row input{width:1.1rem;height:1.1rem}
table{width:100%;border-collapse:collapse;font-size:.88rem;}
th{text-align:left;padding:.65rem .5rem;color:var(--muted);border-bottom:1px solid var(--bd);font-weight:600;font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;}
td{padding:.7rem .5rem;border-bottom:1px solid var(--bd);vertical-align:middle}
tr:last-child td{border-bottom:none}.mono{font-family:ui-monospace,monospace;font-size:.82rem}
.rssi-good{color:var(--cyan)}.rssi-mid{color:var(--warn)}.rssi-bad{color:#ff6b6b}
.empty{text-align:center;padding:2rem 1rem;color:var(--muted);font-size:.95rem;}
.empty .ico{font-size:2.5rem;line-height:1;display:block;margin-bottom:.5rem}
footer{margin-top:1.5rem;font-size:.75rem;color:var(--muted);line-height:1.6}
footer code{background:#12121a;padding:.12rem .35rem;border-radius:6px;border:1px solid var(--bd)}
</style></head><body><div class="wrap">
<header>
<h1>&#x2764;&#xFE0F; &#x1F5A5;&#xFE0F; Herz-Schwarm Basisstation</h1>
<span class="badge">&#x1F4E1; Station FW <strong id="sfw">&hellip;</strong></span>
<span class="badge" id="pulse">&#x1F535; &hellip;</span>
<span class="badge" id="mqstat">MQTT &hellip;</span>
</header>
<div class="grid">
<div class="stat"><div class="big" id="cnt">0</div><div class="lbl">&#x1F4F1; Badges in Sicht</div></div>
<div class="stat"><div class="big" id="sig">&mdash;</div><div class="lbl">&#x1F4F6; bestes RSSI</div></div>
</div>
<div class="card">
<h2>&#x1F384; Eastereggs (ESP-NOW)</h2>
<p style="margin:0 0 .75rem;color:var(--muted);font-size:.88rem">Gleiche Effekte wie am Badge: Morse-Virus, Singularity-Regenbogen (17+ Peers), Primzahl-Sparkles, Welle (RSSI-Ripple) &mdash; plus Beat, Zonen, Ambient-Farbe und Strobe. Modi 5&ndash;8 brauchen Badge-FW &ge; 1.1.</p>
<div class="btn-row">
<button type="button" class="btn" onclick="doEffect(1)">&#x26A1; Virus (wei&szlig;)</button>
<button type="button" class="btn btn-rb" onclick="doEffect(2)">&#x1F308; Regenbogen</button>
<button type="button" class="btn btn-pr" onclick="doEffect(3)">&#x2728; Primzahl-Party</button>
<button type="button" class="btn btn-wv" id="wvbtn" onclick="doEffect(wave?10:4)">&#x1F30A; Welle</button>
</div>
<div class="btn-row">
<button type="button" class="btn btn-bt" onclick="doEffect(5)">&#x1F941; Beat</button>
<button type="button" class="btn btn-zn" onclick="doEffect(6)">&#x1F3AF; Zonen</button>
<span class="amb"><button type="button" class="btn btn-sec" onclick="doEffect(7)">&#x1F3A8; Ambient</button><input type="color" id="ambc" value="#ff2a88" title="Ambient-Farbe"></span>
<button type="button" class="btn btn-st" onclick="doEffect(8)">&#x26A0;&#xFE0F; Strobe</button>
</div>
<p class="warn">&#x26A0;&#xFE0F; Strobe blitzt ~6&times; pro Sekunde &mdash; nicht ausl&ouml;sen, wenn photosensible Menschen in der N&auml;he sind.</p>
<p id="msg"></p>
</div>
<div class="card">
<h2>&#x1F4E6; MQTT-Broker</h2>
<p style="margin:0 0 .5rem;color:var(--muted);font-size:.88rem">Zugangsdaten im Flash (NVS). Passwort: leer lassen = unver&auml;ndert. Klartext-MQTT (z. B. Port 1883). Nach Speichern neu verbinden.</p>
<form id="mqttf">
<div class="chk-row"><input type="checkbox" id="mqen" name="en" value="1"><label for="mqen" style="margin:0;cursor:pointer">MQTT aktiv</label></div>
<div class="form-grid">
<label>Host / IP<input class="inp" type="text" id="mqhost" name="host" autocomplete="off" placeholder="192.168.1.10"></label>
<label>Port<input class="inp" type="number" id="mqport" name="port" min="1" max="65535" value="1883"></label>
<label>Benutzername<input class="inp" type="text" id="mquser" name="user" autocomplete="username"></label>
<label>Passwort<input class="inp" type="password" id="mqpass" name="pass" autocomplete="current-password" placeholder="(leer = behalten)"></label>
<label>Topic Status (Publish)<input class="inp" type="text" id="mqts" name="ts" placeholder="herzschwarm/base/status"></label>
<label>Topic Befehl (Subscribe)<input class="inp" type="text" id="mqtc" name="tc" placeholder="herzschwarm/base/cmd/virus"></label>
</div>
<div class="btn-row">
<button type="submit" class="btn">&#x1F4BE; Speichern</button>
<button type="button" class="btn btn-sec" onclick="loadMqtt(true)">&#x1F504; Neu laden</button>
</div>
</form>
<p id="mqmsg"></p>
</div>
<div class="card">
<h2>&#x1F4BB; Badges in der N&auml;he</h2>
<div id="empty" class="empty" style="display:none"><span class="ico">&#x1F440;</span>Keine Badges in ESP-NOW-Reichweite (Kanal 13)<br><small>Abstand &amp; Antenne pr&uuml;fen &#x1F50D;</small></div>
<table id="tbl"><thead><tr><th>&#x1F4CD; MAC</th><th>&#x1F4F6; RSSI</th><th>&#x1F4E6; Firmware</th><th>&#x23F1;&#xFE0F; &Delta; ms</th><th></th></tr></thead><tbody id="tb"></tbody></table>
<p style="margin:.6rem 0 0;color:var(--muted);font-size:.8rem">&#x1F50E; <b>Finden</b>: das Badge blinkt 10&nbsp;s gr&uuml;n mit voller Helligkeit (Badge-FW &ge; 1.3). Mit dem RSSI-Wert hei&szlig;/kalt suchen.</p>
<p id="findmsg" style="min-height:1.2rem;font-size:.85rem;margin:.4rem 0 0"></p>
</div>
<div class="card">
<h2>&#x2B06;&#xFE0F; Firmware-Update (OTA)</h2>
<p style="margin:0 0 .5rem;color:var(--muted);font-size:.88rem">Datei <code>Herz_Schwarm_BaseStation.ino.bin</code> aus dem Build-Ordner (<code>arduino-cli compile --export-binaries</code> &rarr; <code>build/&hellip;/</code>). Nach dem Upload startet die Station neu.</p>
<form id="otaf">
<div class="form-grid">
<label>Firmware (.bin)<input class="inp" type="file" id="otafile" accept=".bin"></label>
<label>OTA-Passwort<input class="inp" type="password" id="otapw" autocomplete="off"></label>
</div>
<div class="btn-row"><button type="submit" class="btn">&#x2B06;&#xFE0F; Hochladen &amp; neu starten</button></div>
</form>
<p id="otamsg"></p>
<p class="warn" id="otadef" style="display:none">&#x26A0;&#xFE0F; Standard-OTA-Passwort aktiv &mdash; eigenes in <code>ota_secret.h</code> setzen und neu flashen.</p>
</div>
<footer>
&#x1F4CB; API: <code>GET /api/peers</code> &middot; <code>GET/POST /api/mqtt</code> &middot; <code>POST /api/effect?m=1&hellip;8[&amp;c=RRGGBB]</code> (<code>m=10</code> Welle stoppen) &middot; <code>POST /api/identify?mac=&hellip;</code> &middot; <code>POST /api/ota</code><br>
&#x2728; CCC Herz-Schwarm &mdash; HTTP ist unverschl&uuml;sselt; MQTT-Zugang nur im lokalen Netz setzen.
</footer>
</div>
<script>
function rssiClass(v){if(v>=-55)return'rssi-good';if(v>=-75)return'rssi-mid';return'rssi-bad';}
function rssiFace(v){
 if(v>=-55)return'\uD83D\uDE0D';
 if(v>=-75)return'\uD83D\uDE42';
 return'\uD83D\uDE2C';
}
function setMqttBadge(j){
 var el=document.getElementById('mqstat');
 if(!j){el.textContent='MQTT ?';return;}
 if(!j.enabled){el.innerHTML='MQTT aus';return;}
 var dot=j.connected?'\uD83D\uDFE2':'\uD83D\uDFE1';
 el.innerHTML=dot+' MQTT '+(j.connected?'verbunden':'getrennt');
}
async function loadMqtt(showMsg){
 try{
  var r=await fetch('/api/mqtt');var j=await r.json();
  document.getElementById('mqen').checked=!!j.enabled;
  document.getElementById('mqhost').value=j.host||'';
  document.getElementById('mqport').value=j.port||1883;
  document.getElementById('mquser').value=j.user||'';
  document.getElementById('mqpass').value='';
  document.getElementById('mqts').value=j.topic_status||'';
  document.getElementById('mqtc').value=j.topic_cmd||'';
  setMqttBadge(j);
  if(showMsg){var m=document.getElementById('mqmsg');m.textContent='\u2705 Geladen';m.style.color='var(--cyan)';}
 }catch(e){
  document.getElementById('mqstat').textContent='MQTT API Fehler';
 }
}
async function load(){
 var pulse=document.getElementById('pulse');
 pulse.textContent='\uD83D\uDD04 Aktualisiere\u2026';
 try{
  var r=await fetch('/api/peers');var j=await r.json();
  document.getElementById('sfw').textContent=j.station||'?';
  if(j.wave!==wave)setWave(!!j.wave);
  document.getElementById('cnt').textContent=j.n;
  var best=null;
  if(j.peers&&j.peers.length){j.peers.forEach(function(p){if(best===null||p.rssi>best)best=p.rssi;});}
  document.getElementById('sig').textContent=(best!==null)?(best+' dBm'):'\u2014';
  var tb=document.getElementById('tb'),empty=document.getElementById('empty'),tbl=document.getElementById('tbl');
  tb.innerHTML='';
  if(!j.peers||!j.peers.length){empty.style.display='block';tbl.style.display='none';}
  else{empty.style.display='none';tbl.style.display='table';
   j.peers.forEach(function(p){
    var fw=(p.fw!==null&&p.fw!==undefined)?p.fw:'\u2753 unbekannt';
    var tr=document.createElement('tr');
    tr.innerHTML='<td class="mono">\uD83C\uDF81 '+p.mac+'</td><td class="'+rssiClass(p.rssi)+'">'+rssiFace(p.rssi)+' '+p.rssi+' dBm</td><td>\uD83D\uDCE6 '+fw+'</td><td>\u23F1\uFE0F '+p.age_ms+'</td><td><button type="button" class="btn btn-find" onclick="findBadge(\''+p.mac+'\')">\uD83D\uDD0E Finden</button></td>';
    tb.appendChild(tr);
   });}
  pulse.textContent='\uD83D\uDFE2 Live';
  setMqttBadge(j.mqtt);
  document.getElementById('otadef').style.display=j.ota_default?'block':'none';
 }catch(e){pulse.textContent='\u26A0\uFE0F Netz/API';}
}
async function findBadge(mac){
 var m=document.getElementById('findmsg');
 m.textContent='\u23F3 '+mac+' \u2026';m.style.color='var(--warn)';
 try{var r=await fetch('/api/identify?mac='+encodeURIComponent(mac),{method:'POST'});var t=await r.text();
  m.textContent=r.ok?('\uD83D\uDD0E '+mac+' blinkt jetzt 10 s gr\u00FCn'):('\u274C '+t);m.style.color=r.ok?'var(--cyan)':'#ff6b6b';
 }catch(e){m.textContent='\u274C '+e;m.style.color='#ff6b6b';}
}
document.getElementById('otaf').addEventListener('submit',function(ev){
 ev.preventDefault();
 var m=document.getElementById('otamsg'),f=document.getElementById('otafile').files[0];
 if(!f){m.textContent='\u274C Keine Datei gew\u00E4hlt';m.style.color='#ff6b6b';return;}
 var fd=new FormData();fd.append('firmware',f,f.name);
 var x=new XMLHttpRequest();x.open('POST','/api/ota');
 x.setRequestHeader('Authorization','Basic '+btoa('admin:'+document.getElementById('otapw').value));
 x.upload.onprogress=function(e){if(e.lengthComputable){m.textContent='\u23F3 '+Math.round(e.loaded*100/e.total)+' %';m.style.color='var(--warn)';}};
 x.onload=function(){
  if(x.status===200){m.textContent='\u2705 '+x.responseText+' \u2013 Seite l\u00E4dt in 15 s neu';m.style.color='var(--cyan)';setTimeout(function(){location.reload();},15000);}
  else{m.textContent='\u274C '+x.status+' '+x.responseText;m.style.color='#ff6b6b';}
 };
 x.onerror=function(){m.textContent='\u274C Verbindung abgebrochen';m.style.color='#ff6b6b';};
 x.send(fd);
});
var wave=false;
function setWave(on){
 wave=on;
 document.getElementById('wvbtn').innerHTML=on?'&#x23F9;&#xFE0F; Welle stoppen':'&#x1F30A; Welle';
 document.getElementById('wvbtn').style.outline=on?'2px solid #fff':'none';
}
async function doEffect(mode){
 var m=document.getElementById('msg');
 m.textContent='\u23F3 Sende\u2026';m.style.color='var(--warn)';
 var q='m='+encodeURIComponent(mode);
 if(mode===7)q+='&c='+encodeURIComponent(document.getElementById('ambc').value.slice(1));
 try{var r=await fetch('/api/effect?'+q,{method:'POST'});var t=await r.text();
  m.textContent=(r.ok?'\u2705 ':'\u274C ')+t;m.style.color=r.ok?'var(--cyan)':'#ff6b6b';
  if(r.ok&&(mode===4||mode===10))setWave(mode===4);
 }catch(e){m.textContent='\u274C '+e;m.style.color='#ff6b6b';}
}
document.getElementById('mqttf').addEventListener('submit',async function(ev){
 ev.preventDefault();
 var m=document.getElementById('mqmsg');
 m.textContent='\u23F3 Speichere\u2026';m.style.color='var(--warn)';
 var p=new URLSearchParams();
 p.set('en',document.getElementById('mqen').checked?'1':'0');
 p.set('host',document.getElementById('mqhost').value.trim());
 p.set('port',document.getElementById('mqport').value);
 p.set('user',document.getElementById('mquser').value);
 var pw=document.getElementById('mqpass').value;
 if(pw.length)p.set('pass',pw);
 p.set('ts',document.getElementById('mqts').value.trim());
 p.set('tc',document.getElementById('mqtc').value.trim());
 try{
  var r=await fetch('/api/mqtt',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:p.toString()});
  var j=await r.json();
  if(r.ok&&j.ok){m.textContent='\u2705 Gespeichert';m.style.color='var(--cyan)';document.getElementById('mqpass').value='';loadMqtt(false);}
  else{m.textContent='\u274C Fehler';m.style.color='#ff6b6b';}
 }catch(e){m.textContent='\u274C '+e;m.style.color='#ff6b6b';}
});
setInterval(load,1500);load();loadMqtt(false);
</script>
</body></html>
)HTML";
    server.send_P(200, "text/html", page);
}

static void handleApiPeersTable() {
    static PeerEntry snap[MAX_PEERS];
    uint32_t now;
    int n = snapshotActivePeers(snap, &now);
    char json[3072];
    size_t o = 0;
    o += snprintf(json + o, sizeof(json) - o,
                  "{\"station\":\"%u.%u.%u\",\"wave\":%s,\"ota_default\":%s,\"mqtt\":{\"enabled\":%s,\"connected\":%s},\"n\":%d,\"peers\":[",
                  BASESTATION_FW_MAJOR, BASESTATION_FW_MINOR, BASESTATION_FW_PATCH,
                  waveRunning ? "true" : "false",
                  OTA_PASSWORD_IS_DEFAULT ? "true" : "false",
                  mqttCfg.enabled ? "true" : "false",
                  (mqttCfg.enabled && mqtt.connected()) ? "true" : "false",
                  n);

    for (int i = 0; i < n; i++) {
        const PeerEntry &p = snap[i];
        if (i) o += snprintf(json + o, sizeof(json) - o, ",");
        uint32_t age = now - p.lastSeen;
        o += snprintf(json + o, sizeof(json) - o, "{\"mac\":\"");
        appendMac(json, sizeof(json), &o, p.mac);
        if (p.ver_known) {
            if (p.ver_dbg) {
                o += snprintf(json + o, sizeof(json) - o,
                              "\",\"rssi\":%d,\"fw\":\"%u.%u.%02u+\",\"age_ms\":%lu}",
                              p.rssi, p.ver_major, p.ver_minor, p.ver_dbg,
                              (unsigned long)age);
            } else {
                o += snprintf(json + o, sizeof(json) - o,
                              "\",\"rssi\":%d,\"fw\":\"%u.%u.%u\",\"age_ms\":%lu}",
                              p.rssi, p.ver_major, p.ver_minor, p.ver_rel,
                              (unsigned long)age);
            }
        } else {
            o += snprintf(json + o, sizeof(json) - o, "\",\"rssi\":%d,\"fw\":null,\"age_ms\":%lu}",
                          p.rssi, (unsigned long)age);
        }
        if (o >= sizeof(json) - 64) break;
    }
    o += snprintf(json + o, sizeof(json) - o, "]}");
    server.send(200, "application/json", json);
}

static SyncPacket makeSyncPacket(uint8_t mode, uint32_t beatCounter) {
    SyncPacket pkt = {};
    pkt.magic_id = MAGIC_ID;
    pkt.beatCounter = beatCounter;
    pkt.virusID = (uint32_t)esp_random();
    pkt.mode = mode;
    pkt.ver_major = BASESTATION_FW_MAJOR;
    pkt.ver_minor = BASESTATION_FW_MINOR;
    pkt.ver_rel = BASESTATION_FW_PATCH;
    pkt.ver_dbg = 0;
    return pkt;
}

// Nur das Badge mit dieser STA-MAC (wie in /api/peers) blinkt ~10 s grün (Badge-FW >= 1.3).
static bool sendIdentify(const uint8_t *mac) {
    uint8_t buf[sizeof(SyncPacket) + 6];
    SyncPacket pkt = makeSyncPacket(SYNC_MODE_IDENTIFY, 0);
    memcpy(buf, &pkt, sizeof(pkt));
    memcpy(buf + sizeof(pkt), mac, 6);
    bool ok = false;
    for (int i = 0; i < IDENTIFY_REPEATS; i++) {
        if (i) delay(15);
        ok |= (esp_now_send(broadcastMac, buf, sizeof(buf)) == ESP_OK);
    }
    Serial.printf("Identify %02X:%02X:%02X:%02X:%02X:%02X %s\n",
                  mac[0], mac[1], mac[2], mac[3], mac[4], mac[5], ok ? "gesendet" : "fehlgeschlagen");
    return ok;
}

static bool parseMac(const char *s, uint8_t out[6]) {
    unsigned v[6];
    if (sscanf(s, "%2x:%2x:%2x:%2x:%2x:%2x", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5]) != 6) return false;
    for (int i = 0; i < 6; i++) out[i] = (uint8_t)v[i];
    return true;
}

// POST /api/identify?mac=AA:BB:CC:DD:EE:FF
static void handleIdentify() {
    uint8_t mac[6];
    if (!parseMac(server.arg("mac").c_str(), mac)) {
        server.send(400, "text/plain", "mac muss AA:BB:CC:DD:EE:FF sein");
        return;
    }
    if (sendIdentify(mac)) server.send(200, "text/plain", "ok");
    else server.send(500, "text/plain", "esp_now_send fehlgeschlagen");
}

// --- OTA: POST /api/ota (multipart, Feld "firmware"), HTTP Basic Auth OTA_USER/OTA_PASSWORD ---
static bool otaAuthorized = false;

static void handleOtaUpload() {
    HTTPUpload &up = server.upload();
    if (up.status == UPLOAD_FILE_START) {
        otaAuthorized = server.authenticate(OTA_USER, OTA_PASSWORD);
        if (!otaAuthorized) {
            Serial.println("OTA: Passwort falsch, Upload wird verworfen");
            return;
        }
        Serial.printf("OTA: Start %s\n", up.filename.c_str());
        if (!Update.begin(UPDATE_SIZE_UNKNOWN, U_FLASH)) Update.printError(Serial);
    } else if (!otaAuthorized) {
        return;
    } else if (up.status == UPLOAD_FILE_WRITE) {
        if (Update.write(up.buf, up.currentSize) != up.currentSize) Update.printError(Serial);
    } else if (up.status == UPLOAD_FILE_END) {
        if (Update.end(true)) Serial.printf("OTA: %u Byte geschrieben\n", (unsigned)up.totalSize);
        else Update.printError(Serial);
    } else if (up.status == UPLOAD_FILE_ABORTED) {
        Update.abort();
        Serial.println("OTA: Upload abgebrochen");
    }
}

static void handleOtaDone() {
    if (!otaAuthorized) {
        // Kein WWW-Authenticate-Header: sonst öffnet der Browser einen eigenen Login-Dialog
        server.send(401, "text/plain", "Passwort falsch");
        return;
    }
    otaAuthorized = false;
    if (Update.hasError() || !Update.isFinished()) {
        server.send(500, "text/plain", String("Update fehlgeschlagen: ") + Update.errorString());
        return;
    }
    server.send(200, "text/plain", "Update ok, Neustart");
    delay(500);
    ESP.restart();
}

static void sendEffectBroadcast(uint8_t mode, uint32_t beatCounter) {
    if (mode != SYNC_MODE_WAVE_STOP && (mode < 1 || mode > SYNC_MODE_MAX)) mode = 1;
    SyncPacket pkt = makeSyncPacket(mode, beatCounter);
    // Stopp trägt die ID der laufenden Welle (0 = unbekannt, Badges stoppen dann ihre lokale Welle)
    if (mode == SYNC_MODE_WAVE_STOP) pkt.virusID = lastWaveId;
    // Stopp-Welle 3× im Abstand; Badges leiten den Stopp selbst begrenzt weiter
    int repeats = (mode == SYNC_MODE_WAVE_STOP) ? WAVE_STOP_REPEATS : 1;
    bool ok = false;
    for (int i = 0; i < repeats; i++) {
        if (i) delay(WAVE_STOP_GAP_MS);
        ok |= (esp_now_send(broadcastMac, (uint8_t *)&pkt, sizeof(pkt)) == ESP_OK);
    }
    if (!ok) {
        Serial.println("esp_now_send effect failed");
    } else {
        Serial.printf("Effect broadcast mode=%u id=%lu\n", (unsigned)mode, (unsigned long)pkt.virusID);
        if (mode == 4) {
            waveRunning = true;
            lastWaveId = pkt.virusID;
        }
        // waveStopId merken, damit verspätete mode-4-Pakete dieser Welle den UI-Zustand nicht wieder auf "läuft" setzen
        if (mode == SYNC_MODE_WAVE_STOP) {
            waveRunning = false;
            waveStopId = pkt.virusID;
        }
    }
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.printf("Herz-Schwarm Basisstation FW %u.%u.%u\n", BASESTATION_FW_MAJOR, BASESTATION_FW_MINOR, BASESTATION_FW_PATCH);

    loadMqttConfig();
    mqtt.setCallback(mqttCallback);
    mqtt.setBufferSize(MQTT_BUFFER_LEN);

    Network.onEvent(onNetworkEvent);

    applyEspNowRadio();

    if (esp_now_init() != ESP_OK) {
        Serial.println("esp_now_init fehlgeschlagen");
        return;
    }
    esp_now_register_recv_cb(OnDataRecv);

    esp_now_peer_info_t peer = {};
    memset(&peer, 0, sizeof(peer));
    memcpy(peer.peer_addr, broadcastMac, 6);
    peer.channel = CCC_CHANNEL;
    peer.encrypt = false;
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(4, 4, 0)
    peer.ifidx = WIFI_IF_STA;
#endif
    if (esp_now_add_peer(&peer) != ESP_OK) {
        Serial.println("esp_now_add_peer broadcast fehlgeschlagen");
    }

    SPI.begin(ETH_SPI_SCK, ETH_SPI_MISO, ETH_SPI_MOSI);
    if (!ETH.begin(ETH_PHY_TYPE, ETH_PHY_ADDR, ETH_PHY_CS, ETH_PHY_IRQ, ETH_PHY_RST, SPI)) {
        Serial.println("ETH.begin fehlgeschlagen — Pins prüfen (W5500)");
    }

    applyEspNowRadio();

    server.on("/", HTTP_GET, handleRoot);
    server.on("/api/peers", HTTP_GET, handleApiPeersTable);
    server.on("/api/mqtt", HTTP_GET, handleMqttGet);
    server.on("/api/mqtt", HTTP_POST, handleMqttPost);
    server.on("/api/effect", HTTP_POST, handleEffect);
    server.on("/api/virus", HTTP_POST, handleVirus);
    server.on("/api/identify", HTTP_POST, handleIdentify);
    server.on("/api/ota", HTTP_POST, handleOtaDone, handleOtaUpload);
#if OTA_PASSWORD_IS_DEFAULT
    Serial.println("WARNUNG: OTA mit Standard-Passwort, eigenes in ota_secret.h setzen");
#endif
    server.begin();
    Serial.println("HTTP auf :80 (nach ETH-Got-IP erreichbar)");
}

void loop() {
    uint32_t now = millis();
    purgeStalePeers();
    server.handleClient();

    if (ethGotIp) {
        mqttTryConnect();
        mqtt.loop();
        if (mqttCfg.enabled && now - lastMqttPublish >= 5000) {
            lastMqttPublish = now;
            mqttPublishStatus();
        }
    }

    delay(2);
}
