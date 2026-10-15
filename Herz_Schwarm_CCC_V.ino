#include <esp_now.h>
#include <WiFi.h>
#include <FastLED.h>
#include <esp_wifi.h>

// Serial-Ausgaben blockieren und können die Animation ruckeln lassen — Standard: aus.
// Aktivieren: hier auf 1 setzen oder Build-Flag: -DENABLE_SERIAL_DEBUG=1
#ifndef ENABLE_SERIAL_DEBUG
#define ENABLE_SERIAL_DEBUG 0
#endif

/*
 * --- Firmware-Version (siehe README: „Firmware-Version“) ---
 * Git: Release mit Tag v1.0.0 auf main. 1.0.0 = Release-Linie (ESP-NOW Herzschwarm,
 * Primzahl/Singularität, Morse-Virus, optional Serial-Debug).
 *
 * Release-Build (ENABLE_SERIAL_DEBUG=0): Anzeige MAJOR.MINOR.PATCH
 * Debug-Build (ENABLE_SERIAL_DEBUG=1):    Anzeige MAJOR.MINOR.DD — DD zweistellig 01…99
 *
 * Versionsschema A.B.C.D (siehe README "Firmware-Version"):
 *   A = MAJOR: nur auf speziellen Wunsch (Breaking Change / Architektur-Wechsel)
 *   B = MINOR: großes neues Feature (Beispiel: 1.1.0 -> 1.2.0 = TUI)
 *   C = PATCH: kleines Feature / Refactor (max 99, danach B hoch)
 *   D = BUILD: jeder Git-Commit wird hochgezählt, NUR als Git-Tag/Commit-Marker,
 *              NICHT im Firmware-Code (würde bei jedem Commit neu kompiliert
 *              werden müssen). Tag-Format: vA.B.C.D, z. B. v1.2.0.5 = 5
 *              Commits seit 1.2.0 (oder seit letztem A.B.C-Wechsel).
 */
#define FW_VERSION_MAJOR 1
#define FW_VERSION_MINOR   2
#define FW_VERSION_PATCH   3
#define FW_DEBUG_BUILD     1  // Nur Debug-Zweig: bei sichtbarem neuen Debug-Stand +1, max 99

#if FW_DEBUG_BUILD < 1 || FW_DEBUG_BUILD > 99
#error "FW_DEBUG_BUILD muss zwischen 1 und 99 liegen (zweistelliger Debug-Zähler)."
#endif

// --- HARDWARE EINSTELLUNGEN ---
#define LED_PIN     14    // Waveshare S3 Matrix intern
#define NUM_LEDS    64
#define BUTTON_PIN  0     // BOOT-Button
#define BRIGHT_MIN  4   
#define BRIGHT_MAX  130   // Etwas reduziert wegen Hitzeentwicklung S3

// --- CCC & SYNC SETTINGS ---
#define CCC_CHANNEL 13          
#define MAGIC_ID    0x421337CC  
#define PEER_TIMEOUT 4000       // Nach 4 Sek. wird ein verschwundenes Badge gelöscht
#define MAX_PEERS   25
#define SYNC_TX_INTERVAL_MS 50  // 20 Hz Sync-Broadcast (Frame-Rate bleibt 50 Hz)

// Schwarm-Takt: heartBeatState ist ein gemeinsamer Phasen-Zähler, 1 Puls = 65536.
// Empfangene Werte, die vorne liegen, werden übernommen (Max-Regel) → alle Badges
// folgen dem schnellsten. Kleine Abstände weich aufholen, große direkt springen.
#define BEAT_UNITS_PER_PULSE 65536UL
#define BEAT_JUMP_THRESHOLD  (4 * BEAT_UNITS_PER_PULSE)

// Remote-Effekte (Basisstation / kompatibles Paket): mode im SyncPacket
#define SYNC_MODE_VIRUS    1  // weißer Blitz (wie Morse -.-.) — 3 s
#define SYNC_MODE_RAINBOW  2  // Singularity-Regenbogen — 15 s
#define SYNC_MODE_PRIME    3  // Primzahl-Puls + Sparkles — 12 s
#define SYNC_MODE_WAVE     4  // Welle: ripple von Basisstation nach RSSI-Distanz
#define SYNC_MODE_BEAT     5  // Beat-Sync Puls (manuell oder BPM)
#define SYNC_MODE_ZONE     6  // RSSI-Zonen-Farben
#define SYNC_MODE_AMBIENT  7  // Feste Farbe (alle LEDs)
#define SYNC_MODE_STROBE   8  // Strobe-Blitz
#define REMOTE_RAINBOW_MS  15000
#define REMOTE_PRIME_MS    12000
#define WAVE_DURATION_MS   4000
#define WAVE_PULSE_MS      700
#define BEAT_PULSE_MS      150
#define REMOTE_ZONE_MS     5000
#define REMOTE_AMBIENT_MS  30000
#define STROBE_DURATION_MS 2000
#define STROBE_FLASH_MS    80

// Zone colors (compile-time, per badge firmware)
#define ZONE0_COLOR  CRGB(255, 50, 50)   // Nah (RSSI > -55): rot
#define ZONE1_COLOR  CRGB(255, 200, 0)   // Mitte (RSSI > -75): gelb
#define ZONE2_COLOR  CRGB(50, 100, 255)  // Fern  (RSSI <= -75): blau

// --- DATENSTRUKTUR ---
// Alte Firmware: 13 Byte (magic…mode). Neu: +4 Byte Firmware-Stände, packed ohne Padding.
// SyncPacket enthaelt A.B.C (ver_rel=PATCH) + ver_dbg (Debug-Build-Zaehler 1..99 oder 0=Release).
// D (Git-Build-Nummer) wird NICHT per Funk gesendet, nur in Git-Tags gefuehrt (Platz + Kabel-Last).
// ver_rel = PATCH bei Release (ver_dbg==0); ver_dbg 1…99 = Debug-Build (+debug), 0 = Release-Binary.
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

// --- MASKE (Oben definiert für den Compiler) ---
const uint8_t heartMask[8][8] = {
  {0,0,0,0,0,0,0,0}, {0,1,1,0,0,1,1,0}, {1,1,1,1,1,1,1,1}, {1,1,1,1,1,1,1,1},
  {1,1,1,1,1,1,1,1}, {0,1,1,1,1,1,1,0}, {0,0,1,1,1,1,0,0}, {0,0,0,1,1,0,0,0}
};

SyncPacket txData;
CRGB leds[NUM_LEDS];

// --- PEER TRACKING ---
struct PeerTracker {
    uint8_t mac[6];
    uint32_t lastSeen;
    uint8_t ver_major;
    uint8_t ver_minor;
    uint8_t ver_rel;
    uint8_t ver_dbg;
    uint8_t ver_known;  // 1 = mindestens ein Paket mit Versionsfeldern empfangen
};
PeerTracker seenPeers[MAX_PEERS];
uint8_t uniquePeerCount = 0;

// --- VARIABLEN ---
// stateMux schützt alles, was OnDataRecv (WiFi-Task, Core 0) schreibt und loop()
// (Core 1) liest: seenPeers, smoothRSSI, heartBeatState/beatCatchup, fx[], wave*,
// ambient*. loop() kopiert einmal pro Frame unter der Sperre und rendert ohne.
static portMUX_TYPE stateMux = portMUX_INITIALIZER_UNLOCKED;
float smoothRSSI = -95;
uint32_t heartBeatState = 0;     // Schwarm-Phase (siehe BEAT_UNITS_PER_PULSE)
uint32_t beatCatchup = 0;        // noch aufzuholender Vorsprung des schnellsten Peers
static uint32_t frameBeat = 0;   // Snapshot von heartBeatState für den aktuellen Frame
uint8_t hueOffset = 0;
uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// Effect-State-Struct: ersetzt 8× copy-paste Variablen
struct EffectState {
    uint32_t id;
    uint32_t startTime;
    bool active;
};
enum EffectIdx : uint8_t { E_VIRUS=0, E_RAINBOW, E_PRIME, E_WAVE, E_BEAT, E_ZONE, E_AMBIENT, E_STROBE, E_COUNT };
EffectState fx[E_COUNT] = {};
static const uint32_t fxDurationMs[E_COUNT] = {
    3000, REMOTE_RAINBOW_MS, REMOTE_PRIME_MS, WAVE_DURATION_MS,
    BEAT_PULSE_MS, REMOTE_ZONE_MS, REMOTE_AMBIENT_MS, STROBE_DURATION_MS
};

// Wave-spezifisch
uint32_t waveDelay = 0;
bool waveReBroadcastDone = false;
uint32_t waveReBroadcastAt = 0;

// Ambient-spezifisch
uint8_t ambientR = 0, ambientG = 0, ambientB = 0;

// Morse: char-Array statt String (kein Heap)
char morseBuf[12] = {0};
uint8_t morseLen = 0;
uint32_t btnDownTime = 0;
uint32_t lastBtnRelease = 0;

// Primzahl-LUT für 1..26 (MAX_PEERS+1)
static const bool primeLUT[27] = {
    0,0,1,1,0,1,0,1,0,0,  // 0..9
    0,1,0,1,0,0,0,1,0,1,  // 10..19
    0,0,0,1,0,0,0         // 20..26
};

// Herz-Maske als 64-Bit Bitmaske (1 = Herz-Pixel)
static uint64_t heartMask64;

CRGB heartColor = CRGB(255, 0, 150); // Cyber-Pink

#if ENABLE_SERIAL_DEBUG
static void printFwVersionBanner() {
    Serial.printf("Herz-Schwarm FW %u.%u.%02u+debug (RSSI/Morse/Peers siehe Log)\n",
                  FW_VERSION_MAJOR, FW_VERSION_MINOR, FW_DEBUG_BUILD);
}
#endif

static void sendSync(uint8_t mode, uint32_t fxId) {
    txData.magic_id = MAGIC_ID;
    // Ambient: beatCounter trägt die Farbe (0xRRGGBB), sonst den Schwarm-Takt
    portENTER_CRITICAL(&stateMux);
    txData.beatCounter = (mode == SYNC_MODE_AMBIENT)
        ? ((uint32_t)ambientR << 16) | ((uint32_t)ambientG << 8) | ambientB
        : heartBeatState;
    portEXIT_CRITICAL(&stateMux);
    txData.virusID = fxId;
    txData.mode = mode;
    txData.ver_major = FW_VERSION_MAJOR;
    txData.ver_minor = FW_VERSION_MINOR;
    txData.ver_rel = FW_VERSION_PATCH;
#if ENABLE_SERIAL_DEBUG
    txData.ver_dbg = FW_DEBUG_BUILD;
#else
    txData.ver_dbg = 0;
#endif
    // Fehler ignorieren — nächster Sendezyklus sendet wieder
    esp_now_send(broadcastMac, (uint8_t *)&txData, sizeof(txData));
}

// Puls-Helligkeit aus der gemeinsamen Schwarm-Phase (statt beatsin8, das mit dem
// lokalen millis() rechnet und daher nie zwischen Badges synchron ist).
static inline uint8_t swarmPulse(uint8_t lowest, uint8_t highest) {
    return lowest + scale8(sin8((uint8_t)(frameBeat >> 8)), highest - lowest);
}

// --- HELPER: PRIMZAHL (LUT, O(1)) ---
static inline bool isPrimeFast(uint8_t n) {
    return (n < 27) ? primeLUT[n] : false;
}

// --- PEER TRACKING: lineare Suche ---
// Bei MAX_PEERS=25 schneller als jeder Hash und ohne Verwaltungs-Zustand,
// der beim Wiederbelegen freier Slots inkonsistent werden kann. Aufruf unter stateMux.
static void trackBadge(const uint8_t* mac, bool hasVer, uint8_t vmaj, uint8_t vmin, uint8_t vrel,
                       uint8_t vdbg) {
    uint32_t now = millis();
    int slot = -1;
    for (int i = 0; i < MAX_PEERS; i++) {
        if (seenPeers[i].lastSeen == 0) {
            if (slot < 0) slot = i;  // erster freier Slot als Fallback
        } else if (memcmp(seenPeers[i].mac, mac, 6) == 0) {
            slot = i;
            break;
        }
    }
    if (slot < 0) return;  // Tabelle voll
    PeerTracker &p = seenPeers[slot];
    if (p.lastSeen == 0) {
        memcpy(p.mac, mac, 6);
        p.ver_known = 0;
    }
    p.lastSeen = now;
    if (hasVer) {
        p.ver_major = vmaj;
        p.ver_minor = vmin;
        p.ver_rel = vrel;
        p.ver_dbg = vdbg;
        p.ver_known = 1;
    }
}

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
    if (len < (int)SYNC_PACKET_LEGACY_LEN) return;
    if (*(const uint32_t *)incomingData != MAGIC_ID) return;

    SyncPacket rx;
    memset(&rx, 0, sizeof(rx));
    memcpy(&rx, incomingData, (size_t)len < sizeof(rx) ? (size_t)len : sizeof(rx));
    const bool hasVer = (len >= (int)sizeof(SyncPacket));

    const float currentRSSI = (float)recv_info->rx_ctrl->rssi;
    const uint32_t now = millis();

    portENTER_CRITICAL(&stateMux);
    trackBadge(recv_info->src_addr, hasVer, rx.ver_major, rx.ver_minor, rx.ver_rel, rx.ver_dbg);

    smoothRSSI = (0.05f * currentRSSI) + (0.95f * smoothRSSI);
    if (rx.mode != SYNC_MODE_AMBIENT) {  // bei Ambient ist beatCounter eine Farbe
        int32_t ahead = (int32_t)(rx.beatCounter - heartBeatState);
        if (ahead > (int32_t)BEAT_JUMP_THRESHOLD) {
            heartBeatState = rx.beatCounter;
            beatCatchup = 0;
        } else if (ahead > 0 && (uint32_t)ahead > beatCatchup) {
            beatCatchup = (uint32_t)ahead;
        }
    }

    #define FX_START(idx, rxid) do { if ((rxid) != fx[idx].id) { fx[idx].id = (rxid); fx[idx].startTime = now; fx[idx].active = true; } } while(0)

    if (rx.mode == SYNC_MODE_VIRUS)   FX_START(E_VIRUS,   rx.virusID);
    if (rx.mode == SYNC_MODE_RAINBOW) FX_START(E_RAINBOW, rx.virusID);
    if (rx.mode == SYNC_MODE_PRIME)   FX_START(E_PRIME,   rx.virusID);
    if (rx.mode == SYNC_MODE_WAVE && rx.virusID != fx[E_WAVE].id) {
        fx[E_WAVE].id = rx.virusID;
        float inputRSSI = constrain(smoothRSSI, -95.0f, -45.0f);
        float norm = (inputRSSI - (-95.0f)) / 50.0f;
        waveDelay = (uint32_t)((1.0f - norm) * (float)(WAVE_DURATION_MS - WAVE_PULSE_MS));
        fx[E_WAVE].startTime = now;
        fx[E_WAVE].active = true;
        waveReBroadcastDone = false;
    }
    if (rx.mode == SYNC_MODE_BEAT)    FX_START(E_BEAT,    rx.virusID);
    if (rx.mode == SYNC_MODE_ZONE)    FX_START(E_ZONE,    rx.virusID);
    if (rx.mode == SYNC_MODE_AMBIENT && rx.virusID != fx[E_AMBIENT].id) {
        fx[E_AMBIENT].id = rx.virusID;
        fx[E_AMBIENT].startTime = now;
        fx[E_AMBIENT].active = true;
        ambientR = (rx.beatCounter >> 16) & 0xFF;
        ambientG = (rx.beatCounter >> 8) & 0xFF;
        ambientB = rx.beatCounter & 0xFF;
    }
    if (rx.mode == SYNC_MODE_STROBE)  FX_START(E_STROBE,  rx.virusID);
    #undef FX_START
    portEXIT_CRITICAL(&stateMux);
}

void setup() {
#if ENABLE_SERIAL_DEBUG
    Serial.begin(115200);
    printFwVersionBanner();
#endif
    pinMode(BUTTON_PIN, INPUT_PULLUP);

    // Herz-Bitmaske einmalig aus Array aufbauen
    for (int i = 0; i < 64; i++) {
        if (heartMask[i / 8][i % 8]) heartMask64 |= (1ULL << i);
    }

    WiFi.mode(WIFI_STA);
    // 11B ist Pflicht: ESP-IDF 5.x lehnt G|N ohne B mit ESP_ERR_INVALID_ARG ab.
    esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
    esp_wifi_set_channel(CCC_CHANNEL, WIFI_SECOND_CHAN_NONE);
    esp_wifi_set_max_tx_power(52);
    WiFi.setSleep(false);

    if (esp_now_init() != ESP_OK) return;

    esp_now_peer_info_t peerInfo = {};
    memcpy(peerInfo.peer_addr, broadcastMac, 6);
    peerInfo.channel = CCC_CHANNEL;
    peerInfo.encrypt = false;
    esp_now_add_peer(&peerInfo);
    esp_now_register_recv_cb(OnDataRecv);

    // WICHTIG: GRB für Waveshare Matrix
    FastLED.addLeds<WS2812B, LED_PIN, BGR>(leds, NUM_LEDS);
    FastLED.clear();
    FastLED.show();
}

void loop() {
    uint32_t now = millis();

    // 1. MORSE ERKENNUNG (char-Array statt String)
    bool btn = (digitalRead(BUTTON_PIN) == LOW);
    if (btn && btnDownTime == 0) btnDownTime = now;
    if (!btn && btnDownTime != 0) {
        uint32_t duration = now - btnDownTime;
        char sym = (duration > 250) ? '-' : '.';
        if (morseLen < sizeof(morseBuf) - 1) {
            morseBuf[morseLen++] = sym;
            morseBuf[morseLen] = '\0';
        }
#if ENABLE_SERIAL_DEBUG
        Serial.printf("[Morse] +%c (%lu ms) Puffer: \"%s\"\n",
                      sym, (unsigned long)duration, morseBuf);
#endif
        btnDownTime = 0;
        lastBtnRelease = now;
    }
    if (morseLen > 0 && (now - lastBtnRelease > 800)) {
        if (strcmp(morseBuf, "-.-.") == 0) {
            uint32_t id = (uint32_t)(esp_random() % 99999) + 1;
            portENTER_CRITICAL(&stateMux);
            fx[E_VIRUS].id = id;
            fx[E_VIRUS].startTime = now;
            fx[E_VIRUS].active = true;
            portEXIT_CRITICAL(&stateMux);
#if ENABLE_SERIAL_DEBUG
            Serial.println("[Morse] Wortende -> VIRUS (-.-.)");
#endif
        }
#if ENABLE_SERIAL_DEBUG
        else {
            Serial.printf("[Morse] Wortende -> ignoriert (\"%s\")\n", morseBuf);
        }
#endif
        morseLen = 0;
        morseBuf[0] = '\0';
    }

    // 2.–4. GEMEINSAMER ZUSTAND: aktualisieren + Snapshot für den Frame (unter stateMux)
    float inputRSSI, norm, power;
    float rssiSnapshot;
    static uint32_t lastBeatMs = now;
    static uint8_t modeBpm = 35;
    EffectState fs[E_COUNT];
    uint32_t waveDelayS;
    bool waveStartRebroadcast;
    uint8_t ambR, ambG, ambB;

    // Kurz halten: nur Zählen, ein paar float-Operationen und Kopien, keine I/O.
    portENTER_CRITICAL(&stateMux);
    // now neu lesen: OnDataRecv kann seit Loop-Beginn lastSeen/startTime auf einen
    // späteren Wert gesetzt haben, now - x würde sonst überlaufen (Peer/Effekt weg).
    now = millis();

    // 2. PEER COUNT & TIMEOUT CLEANUP
    uniquePeerCount = 0;
    for (int i = 0; i < MAX_PEERS; i++) {
        if (seenPeers[i].lastSeen != 0) {
            if (now - seenPeers[i].lastSeen > PEER_TIMEOUT) {
                seenPeers[i].lastSeen = 0;  // lastSeen==0 = Slot frei
            } else {
                uniquePeerCount++;
            }
        }
    }

    // 3. DYNAMISCHES FADE-OUT
    if (uniquePeerCount == 0) {
        if (smoothRSSI > -95) smoothRSSI -= 0.5f;
    } else {
        smoothRSSI -= 0.01f;
    }
    if (smoothRSSI < -95) smoothRSSI = -95;
    rssiSnapshot = smoothRSSI;

    // 4. RSSI MAPPING + Takt fortschreiben: Modus-Tempo des letzten Frames + RSSI-Anteil
    inputRSSI = constrain(rssiSnapshot, -95, -45);
    norm = (inputRSSI - (-95)) / 50.0f;
    power = norm * norm;
    {
        float bpm = modeBpm + 23.4f + 117.2f * power;
        uint32_t beatStep = (uint32_t)(bpm * (float)(now - lastBeatMs) * (BEAT_UNITS_PER_PULSE / 60000.0f));
        uint32_t catchStep = beatCatchup ? beatCatchup / 4 + 1 : 0;
        if (catchStep > beatCatchup) catchStep = beatCatchup;
        beatCatchup -= catchStep;
        heartBeatState += beatStep + catchStep;
    }
    lastBeatMs = now;
    frameBeat = heartBeatState;

    // Abgelaufene Effekte deaktivieren, Snapshot für das Rendern
    for (int i = 0; i < E_COUNT; i++) {
        if (fx[i].active && now - fx[i].startTime >= fxDurationMs[i]) fx[i].active = false;
        fs[i] = fx[i];
    }
    waveDelayS = waveDelay;
    ambR = ambientR; ambG = ambientG; ambB = ambientB;
    // Wave-Rebroadcast einmal pro Welle einplanen, sobald unser Puls dran ist
    waveStartRebroadcast = fs[E_WAVE].active && !waveReBroadcastDone &&
                           now - fs[E_WAVE].startTime >= waveDelay;
    if (waveStartRebroadcast) waveReBroadcastDone = true;

    portEXIT_CRITICAL(&stateMux);

    if (waveStartRebroadcast) waveReBroadcastAt = now + random(5, 25);
    uint8_t currentBright = BRIGHT_MIN + (uint8_t)(power * (BRIGHT_MAX - BRIGHT_MIN));

    // 5. ANIMATIONS-WEICHE
    FastLED.clear();
    uint8_t pulse = 0;
    uint8_t activeMode = 0;      // für txData.mode
    uint32_t activeFxId = 0;     // für txData.virusID

    if (fs[E_VIRUS].active && (now - fs[E_VIRUS].startTime < 3000)) {
        // MORSE / REMOTE VIRUS BLITZ
        uint32_t flash = (now - fs[E_VIRUS].startTime) % 300;
        if (flash < 150) fill_solid(leds, NUM_LEDS, CRGB::White);
        activeMode = SYNC_MODE_VIRUS;
        activeFxId = fs[E_VIRUS].id;
    }
    else if (fs[E_RAINBOW].active && (now - fs[E_RAINBOW].startTime < REMOTE_RAINBOW_MS)) {
        hueOffset += 5;
        modeBpm = 100;
        pulse = swarmPulse(150, 255);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hueOffset + (i*3), 255, pulse);
        activeMode = SYNC_MODE_RAINBOW;
        activeFxId = fs[E_RAINBOW].id;
    }
    else if (fs[E_PRIME].active && (now - fs[E_PRIME].startTime < REMOTE_PRIME_MS)) {
        modeBpm = 80;
        pulse = swarmPulse(120, 255);
        fill_solid(leds, NUM_LEDS, heartColor);
        nscale8(leds, NUM_LEDS, pulse);
        if (random8() > 210) leds[random8(64)] = CRGB::White;
        activeMode = SYNC_MODE_PRIME;
        activeFxId = fs[E_PRIME].id;
    }
    else if (fs[E_WAVE].active && (now - fs[E_WAVE].startTime < WAVE_DURATION_MS)) {
        uint32_t elapsed = now - fs[E_WAVE].startTime;
        if (elapsed >= waveDelayS && elapsed < waveDelayS + WAVE_PULSE_MS) {
            uint32_t pulseElapsed = elapsed - waveDelayS;
            uint8_t brightness;
            if (pulseElapsed < 200) {
                brightness = (uint8_t)((pulseElapsed * 255) / 200);
            } else if (pulseElapsed < 500) {
                brightness = 255;
            } else {
                brightness = (uint8_t)(((WAVE_PULSE_MS - pulseElapsed) * 255) / 200);
            }
            fill_solid(leds, NUM_LEDS, CRGB(100, 150, 255));
            nscale8(leds, NUM_LEDS, brightness);
        }
        activeMode = SYNC_MODE_WAVE;
        activeFxId = fs[E_WAVE].id;
    }
    else if (fs[E_BEAT].active && (now - fs[E_BEAT].startTime < BEAT_PULSE_MS)) {
        uint32_t elapsed = now - fs[E_BEAT].startTime;
        uint8_t brightness;
        if (elapsed < BEAT_PULSE_MS / 2) {
            brightness = (uint8_t)((elapsed * 255) / (BEAT_PULSE_MS / 2));
        } else {
            brightness = (uint8_t)(((BEAT_PULSE_MS - elapsed) * 255) / (BEAT_PULSE_MS / 2));
        }
        fill_solid(leds, NUM_LEDS, CRGB::White);
        nscale8(leds, NUM_LEDS, brightness);
        activeMode = SYNC_MODE_BEAT;
        activeFxId = fs[E_BEAT].id;
    }
    else if (fs[E_ZONE].active && (now - fs[E_ZONE].startTime < REMOTE_ZONE_MS)) {
        CRGB zoneColor;
        if (rssiSnapshot > -55) zoneColor = ZONE0_COLOR;
        else if (rssiSnapshot > -75) zoneColor = ZONE1_COLOR;
        else zoneColor = ZONE2_COLOR;
        modeBpm = 60;
        pulse = swarmPulse(150, 255);
        fill_solid(leds, NUM_LEDS, zoneColor);
        nscale8(leds, NUM_LEDS, pulse);
        activeMode = SYNC_MODE_ZONE;
        activeFxId = fs[E_ZONE].id;
    }
    else if (fs[E_AMBIENT].active && (now - fs[E_AMBIENT].startTime < REMOTE_AMBIENT_MS)) {
        fill_solid(leds, NUM_LEDS, CRGB(ambR, ambG, ambB));
        activeMode = SYNC_MODE_AMBIENT;
        activeFxId = fs[E_AMBIENT].id;
    }
    else if (fs[E_STROBE].active && (now - fs[E_STROBE].startTime < STROBE_DURATION_MS)) {
        uint32_t elapsed = now - fs[E_STROBE].startTime;
        if ((elapsed / STROBE_FLASH_MS) % 2 == 0) {
            fill_solid(leds, NUM_LEDS, CRGB::White);
        }
        activeMode = SYNC_MODE_STROBE;
        activeFxId = fs[E_STROBE].id;
    }
    else if (uniquePeerCount + 1 >= 17) {
        // THE SINGULARITY
        hueOffset += 5;
        modeBpm = 100;
        pulse = swarmPulse(150, 255);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hueOffset + (i*3), 255, pulse);
        activeMode = 0;
    }
    else {
        uint8_t totalDevices = uniquePeerCount + 1;
        bool prime = isPrimeFast(totalDevices);
        modeBpm = prime ? 80 : 35 + (uint8_t)(power * 55);
        pulse = prime ? swarmPulse(120, 255) : swarmPulse(100, 255);
        fill_solid(leds, NUM_LEDS, heartColor);
        nscale8(leds, NUM_LEDS, pulse);
        if (prime && random8() > 210) leds[random8(64)] = CRGB::White;
        activeMode = 0;
    }

    // Maske: Bitmaske statt 2D-Array-Lookup
    for (int i = 0; i < 64; i++) {
        if (!((heartMask64 >> i) & 1)) leds[i] = CRGB::Black;
    }

    // 6. SENDEN (nicht-blockierend geplant für Wave-Rebroadcast)
    if (waveReBroadcastAt != 0 && (int32_t)(now - waveReBroadcastAt) >= 0) {
        sendSync(SYNC_MODE_WAVE, fs[E_WAVE].id);
        waveReBroadcastAt = 0;
    }

    // Gedrosselt auf SYNC_TX_INTERVAL_MS; Effekt-/ID-Wechsel sofort, damit sich
    // Effekte ohne Verzögerung durch den Schwarm verbreiten.
    static uint32_t lastTx = 0;
    if (now - lastTx >= SYNC_TX_INTERVAL_MS ||
        activeMode != txData.mode || activeFxId != txData.virusID) {
        sendSync(activeMode, activeFxId);
        lastTx = now;
    }

    // 7. OUTPUT
    FastLED.setBrightness(currentBright);
    FastLED.show();

#if ENABLE_SERIAL_DEBUG
    // Nur wenn ENABLE_SERIAL_DEBUG=1: kompletter Block fehlt sonst im Binary — keine Extra-Arbeit für die Animation.
    static uint32_t lastStatusLog = 0;
    if (now - lastStatusLog >= 2000) {
        lastStatusLog = now;
        char line[200];
        int n = snprintf(line, sizeof(line),
                         "Status | FW %u.%u.%02u+debug | Peers: %d | RSSI: %.1f | Bright: %d | Morse: \"%s\" | remote",
                         FW_VERSION_MAJOR, FW_VERSION_MINOR, FW_DEBUG_BUILD,
                         uniquePeerCount, rssiSnapshot, currentBright, morseBuf);
        static PeerTracker peerCopy[MAX_PEERS];
        portENTER_CRITICAL(&stateMux);
        memcpy(peerCopy, seenPeers, sizeof(peerCopy));
        portEXIT_CRITICAL(&stateMux);
        int listed = 0;
        for (int i = 0; i < MAX_PEERS && n < (int)sizeof(line) - 12 && listed < 10; i++) {
            if (peerCopy[i].lastSeen == 0) continue;
            if (peerCopy[i].ver_known) {
                if (peerCopy[i].ver_dbg) {
                    n += snprintf(line + n, sizeof(line) - (size_t)n, " %u.%u.%02u+",
                                  peerCopy[i].ver_major, peerCopy[i].ver_minor, peerCopy[i].ver_dbg);
                } else {
                    n += snprintf(line + n, sizeof(line) - (size_t)n, " %u.%u.%u",
                                  peerCopy[i].ver_major, peerCopy[i].ver_minor, peerCopy[i].ver_rel);
                }
            } else {
                n += snprintf(line + n, sizeof(line) - (size_t)n, " ?");
            }
            listed++;
        }
        Serial.println(line);
    }
#endif

    // 20 ms Frame-Limit, aber nicht blockierend für Watchdog
    static uint32_t lastFrame = 0;
    uint32_t frameTime = now - lastFrame;
    if (frameTime < 20) {
        delay(20 - frameTime);
    }
    lastFrame = millis();
}