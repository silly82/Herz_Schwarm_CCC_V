/**
 * Herz-Schwarm Basisstation (ESP32-S3 + W5500 Ethernet, z. B. Spotpear ESP32-S3-ETH)
 *
 * - Lauscht ESP-NOW auf Kanal 13 (kompatibel zu Herz_Schwarm_CCC_V Badges).
 * - Keine regelmäßigen Sends → erscheint nicht in der Peer-Zählung der Badges.
 * - Optional: Effekt-Broadcast (SyncPacket mode 1=Virus, 2=Regenbogen, 3=Primzahl-Party).
 * - Web-UI + JSON-API; MQTT optional, Broker/Zugangsdaten/Topics per Web-UI (NVS).
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

#define STATION_FW_MAJOR 0
#define STATION_FW_MINOR     1
#define STATION_FW_PATCH     6

#define MQTT_NS "hs_mqtt"
#define MQTT_HOST_DEF    "192.168.1.10"
#define MQTT_TOPIC_STATUS_DEF "herzschwarm/base/status"
#define MQTT_TOPIC_CMD_DEF    "herzschwarm/base/cmd/virus"

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

static void sendEffectBroadcast(uint8_t mode);
static void loadMqttConfig();
static bool resolveMqttBroker(IPAddress &out);
static void mqttCallback(char *topic, byte *payload, unsigned int len);
static void appendJsonString(char *buf, size_t cap, size_t *off, const char *s);

// WiFi/ESP-NOW wie Badge-Sketch; nach ETH-Start erneut aufrufen (Stack kann Kanal zurücksetzen).
static void applyEspNowRadio() {
    WiFi.mode(WIFI_STA);
    if (esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N) != ESP_OK) {
        Serial.println("esp_wifi_set_protocol fehlgeschlagen");
    }
    esp_err_t err = esp_wifi_set_channel(CCC_CHANNEL, WIFI_SECOND_CHAN_NONE);
    if (err != ESP_OK) {
        Serial.printf("esp_wifi_set_channel fehlgeschlagen: %d\n", (int)err);
    }
    esp_wifi_set_max_tx_power(52);
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
            ETH.setHostname("herz-base");
            break;
        case ARDUINO_EVENT_ETH_GOT_IP:
            ethGotIp = true;
            Serial.print("ETH IP: ");
            Serial.println(ETH);
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

static int countActivePeers(uint32_t now) {
    int n = 0;
    for (int i = 0; i < MAX_PEERS; i++) {
        if (peers[i].in_use && (now - peers[i].lastSeen) <= PEER_TIMEOUT_MS) n++;
    }
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

static void purgeStalePeers(uint32_t now) {
    portENTER_CRITICAL(&peerMux);
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
}

static void appendMac(char *buf, size_t buflen, size_t *off, const uint8_t *mac) {
    *off += snprintf(buf + *off, buflen - *off, "%02X:%02X:%02X:%02X:%02X:%02X",
                     mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static void handleVirus() {
    sendEffectBroadcast(1);
    server.send(200, "text/plain", "ok");
}

static void handleEffect() {
    int m = server.arg("m").toInt();
    if (m < 1 || m > 3) m = 1;
    sendEffectBroadcast((uint8_t)m);
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

static void mqttCallback(char *topic, byte *payload, unsigned int len) {
    (void)payload;
    (void)len;
    if (strcmp(topic, mqttCfg.topicCmd) == 0) {
        sendEffectBroadcast(1);
    }
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
    mqtt.setBufferSize(768);

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
    uint32_t now = millis();
    char json[2048];
    size_t o = 0;
    o += snprintf(json + o, sizeof(json) - o, "{\"n\":%d,\"peers\":[", countActivePeers(now));
    bool first = true;
    portENTER_CRITICAL(&peerMux);
    for (int i = 0; i < MAX_PEERS; i++) {
        if (!peers[i].in_use || (now - peers[i].lastSeen) > PEER_TIMEOUT_MS) continue;
        if (!first) o += snprintf(json + o, sizeof(json) - o, ",");
        first = false;
        o += snprintf(json + o, sizeof(json) - o, "{\"mac\":\"");
        appendMac(json, sizeof(json), &o, peers[i].mac);
        o += snprintf(json + o, sizeof(json) - o, "\",\"rssi\":%d}", peers[i].rssi);
        if (o >= sizeof(json) - 32) break;
    }
    portEXIT_CRITICAL(&peerMux);
    o += snprintf(json + o, sizeof(json) - o, "]}");
    mqtt.publish(mqttCfg.topicStatus, json);
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
.btn-sec{background:linear-gradient(135deg,#3d3d52,#52526b);box-shadow:0 2px 12px rgba(0,0,0,.25)}
#msg,#mqmsg{min-height:1.4rem;font-size:.88rem;color:var(--cyan);margin:.5rem 0 0;}
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
<p style="margin:0 0 .75rem;color:var(--muted);font-size:.88rem">Gleiche Effekte wie am Badge: Morse-Virus, Singularity-Regenbogen (17+ Peers), Primzahl-Sparkles &mdash; hier per Funk ausl&ouml;sen. Badges brauchen passende Firmware (Modi 1&ndash;3).</p>
<div class="btn-row">
<button type="button" class="btn" onclick="doEffect(1)">&#x26A1; Virus (wei&szlig;)</button>
<button type="button" class="btn btn-rb" onclick="doEffect(2)">&#x1F308; Regenbogen</button>
<button type="button" class="btn btn-pr" onclick="doEffect(3)">&#x2728; Primzahl-Party</button>
</div>
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
<table id="tbl"><thead><tr><th>&#x1F4CD; MAC</th><th>&#x1F4F6; RSSI</th><th>&#x1F4E6; Firmware</th><th>&#x23F1;&#xFE0F; &Delta; ms</th></tr></thead><tbody id="tb"></tbody></table>
</div>
<footer>
&#x1F4CB; API: <code>GET /api/peers</code> &middot; <code>GET/POST /api/mqtt</code> &middot; <code>POST /api/effect?m=1|2|3</code><br>
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
    tr.innerHTML='<td class="mono">\uD83C\uDF81 '+p.mac+'</td><td class="'+rssiClass(p.rssi)+'">'+rssiFace(p.rssi)+' '+p.rssi+' dBm</td><td>\uD83D\uDCE6 '+fw+'</td><td>\u23F1\uFE0F '+p.age_ms+'</td>';
    tb.appendChild(tr);
   });}
  pulse.textContent='\uD83D\uDFE2 Live';
  var rm=await fetch('/api/mqtt');setMqttBadge(await rm.json());
 }catch(e){pulse.textContent='\u26A0\uFE0F Netz/API';}
}
async function doEffect(mode){
 var m=document.getElementById('msg');
 m.textContent='\u23F3 Sende\u2026';m.style.color='var(--warn)';
 try{var r=await fetch('/api/effect?m='+encodeURIComponent(mode),{method:'POST'});var t=await r.text();
  m.textContent=(r.ok?'\u2705 ':'\u274C ')+t;m.style.color=r.ok?'var(--cyan)':'#ff6b6b';
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
    uint32_t now = millis();
    char json[3072];
    size_t o = 0;
    o += snprintf(json + o, sizeof(json) - o, "{\"station\":\"%u.%u.%u\",\"n\":%d,\"peers\":[",
                  STATION_FW_MAJOR, STATION_FW_MINOR, STATION_FW_PATCH, countActivePeers(now));

    bool first = true;
    portENTER_CRITICAL(&peerMux);
    for (int i = 0; i < MAX_PEERS; i++) {
        if (!peers[i].in_use || (now - peers[i].lastSeen) > PEER_TIMEOUT_MS) continue;
        if (!first) o += snprintf(json + o, sizeof(json) - o, ",");
        first = false;
        uint32_t age = now - peers[i].lastSeen;
        o += snprintf(json + o, sizeof(json) - o, "{\"mac\":\"");
        appendMac(json, sizeof(json), &o, peers[i].mac);
        if (peers[i].ver_known) {
            if (peers[i].ver_dbg) {
                o += snprintf(json + o, sizeof(json) - o,
                              "\",\"rssi\":%d,\"fw\":\"%u.%u.%02u+\",\"age_ms\":%lu}",
                              peers[i].rssi, peers[i].ver_major, peers[i].ver_minor, peers[i].ver_dbg,
                              (unsigned long)age);
            } else {
                o += snprintf(json + o, sizeof(json) - o,
                              "\",\"rssi\":%d,\"fw\":\"%u.%u.%u\",\"age_ms\":%lu}",
                              peers[i].rssi, peers[i].ver_major, peers[i].ver_minor, peers[i].ver_rel,
                              (unsigned long)age);
            }
        } else {
            o += snprintf(json + o, sizeof(json) - o, "\",\"rssi\":%d,\"fw\":null,\"age_ms\":%lu}",
                          peers[i].rssi, (unsigned long)age);
        }
        if (o >= sizeof(json) - 64) break;
    }
    portEXIT_CRITICAL(&peerMux);
    o += snprintf(json + o, sizeof(json) - o, "]}");
    server.send(200, "application/json", json);
}

static void sendEffectBroadcast(uint8_t mode) {
    if (mode < 1 || mode > 3) mode = 1;
    SyncPacket pkt = {};
    pkt.magic_id = MAGIC_ID;
    pkt.beatCounter = (uint32_t)millis();
    pkt.virusID = (uint32_t)(random(1, 100000));
    pkt.mode = mode;
    pkt.ver_major = STATION_FW_MAJOR;
    pkt.ver_minor = STATION_FW_MINOR;
    pkt.ver_rel = STATION_FW_PATCH;
    pkt.ver_dbg = 0;
    if (esp_now_send(broadcastMac, (uint8_t *)&pkt, sizeof(pkt)) != ESP_OK) {
        Serial.println("esp_now_send effect failed");
    } else {
        Serial.printf("Effect broadcast mode=%u id=%lu\n", (unsigned)mode, (unsigned long)pkt.virusID);
    }
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.printf("Herz-Schwarm Basisstation FW %u.%u.%u\n", STATION_FW_MAJOR, STATION_FW_MINOR, STATION_FW_PATCH);

    loadMqttConfig();
    mqtt.setCallback(mqttCallback);

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
    server.begin();
    Serial.println("HTTP auf :80 (nach ETH-Got-IP erreichbar)");
}

void loop() {
    uint32_t now = millis();
    purgeStalePeers(now);
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
