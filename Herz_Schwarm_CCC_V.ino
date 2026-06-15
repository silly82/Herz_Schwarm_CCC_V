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
 */
#define FW_VERSION_MAJOR 1
#define FW_VERSION_MINOR   0
#define FW_VERSION_PATCH   0
#define FW_DEBUG_BUILD     2  // Nur Debug-Zweig: bei sichtbarem neuen Debug-Stand +1, max 99

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
// ver_rel = PATCH bei Release (ver_dbg==0); ver_dbg 1…99 = Debug-Build (+debug),0 = Release-Binary.
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
float smoothRSSI = -95;   
uint32_t heartBeatState = 0; 
uint8_t hueOffset = 0;
uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
uint32_t activeVirusID = 0;
uint32_t virusStartTime = 0;
uint32_t activeRainbowID = 0;
uint32_t rainbowStartTime = 0;
uint32_t activePrimeID = 0;
uint32_t primePartyStartTime = 0;
uint32_t activeWaveID = 0;
uint32_t waveStartTime = 0;
uint32_t waveDelay = 0;
bool waveActive = false;
bool waveReBroadcastDone = false;
uint32_t activeBeatID = 0;
uint32_t beatStartTime = 0;
bool beatActive = false;
uint32_t activeZoneID = 0;
uint32_t zoneStartTime = 0;
bool zoneActive = false;
uint32_t activeAmbientID = 0;
uint32_t ambientStartTime = 0;
bool ambientActive = false;
uint8_t ambientR = 0, ambientG = 0, ambientB = 0;
uint32_t activeStrobeID = 0;
uint32_t strobeStartTime = 0;
bool strobeActive = false;

// Morse Variablen
uint32_t btnDownTime = 0;
String morseInput = "";
uint32_t lastBtnRelease = 0;

CRGB heartColor = CRGB(255, 0, 150); // Cyber-Pink

#if ENABLE_SERIAL_DEBUG
static void printFwVersionBanner() {
    Serial.printf("Herz-Schwarm FW %u.%u.%02u+debug (RSSI/Morse/Peers siehe Log)\n",
                  FW_VERSION_MAJOR, FW_VERSION_MINOR, FW_DEBUG_BUILD);
}
#endif

// --- HELPER: PRIMZAHL ---
bool isPrime(int n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (int i = 5; i * i <= n; i += 6) if (n % i == 0 || n % (i + 2) == 0) return false;
    return true;
}

// --- PEER TRACKING LOGIK ---
static void trackBadge(const uint8_t* mac, bool hasVer, uint8_t vmaj, uint8_t vmin, uint8_t vrel,
                       uint8_t vdbg) {
    uint32_t now = millis();
    for (int i = 0; i < MAX_PEERS; i++) {
        if (memcmp(seenPeers[i].mac, mac, 6) == 0) {
            seenPeers[i].lastSeen = now;
            if (hasVer) {
                seenPeers[i].ver_major = vmaj;
                seenPeers[i].ver_minor = vmin;
                seenPeers[i].ver_rel = vrel;
                seenPeers[i].ver_dbg = vdbg;
                seenPeers[i].ver_known = 1;
            }
            return;
        }
    }
    for (int i = 0; i < MAX_PEERS; i++) {
        if (seenPeers[i].lastSeen == 0) {
            memcpy(seenPeers[i].mac, mac, 6);
            seenPeers[i].lastSeen = now;
            if (hasVer) {
                seenPeers[i].ver_major = vmaj;
                seenPeers[i].ver_minor = vmin;
                seenPeers[i].ver_rel = vrel;
                seenPeers[i].ver_dbg = vdbg;
                seenPeers[i].ver_known = 1;
            }
            return;
        }
    }
}

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
    if (len < (int)SYNC_PACKET_LEGACY_LEN) return;
    if (*(const uint32_t *)incomingData != MAGIC_ID) return;

    SyncPacket rx;
    memset(&rx, 0, sizeof(rx));
    memcpy(&rx, incomingData, (size_t)len < sizeof(rx) ? (size_t)len : sizeof(rx));
    const bool hasVer = (len >= (int)sizeof(SyncPacket));

    trackBadge(recv_info->src_addr, hasVer, rx.ver_major, rx.ver_minor, rx.ver_rel, rx.ver_dbg);

    float currentRSSI = (float)recv_info->rx_ctrl->rssi;
    smoothRSSI = (0.05 * currentRSSI) + (0.95 * smoothRSSI);
    heartBeatState = rx.beatCounter;

    if (rx.mode == SYNC_MODE_VIRUS && rx.virusID != activeVirusID) {
        activeVirusID = rx.virusID;
        virusStartTime = millis();
    }
    if (rx.mode == SYNC_MODE_RAINBOW && rx.virusID != activeRainbowID) {
        activeRainbowID = rx.virusID;
        rainbowStartTime = millis();
    }
    if (rx.mode == SYNC_MODE_PRIME && rx.virusID != activePrimeID) {
        activePrimeID = rx.virusID;
        primePartyStartTime = millis();
    }
    if (rx.mode == SYNC_MODE_WAVE && rx.virusID != activeWaveID) {
        activeWaveID = rx.virusID;
        float inputRSSI = constrain(smoothRSSI, -95.0f, -45.0f);
        float norm = (inputRSSI - (-95.0f)) / (-45.0f - (-95.0f));
        waveDelay = (uint32_t)((1.0f - norm) * (float)(WAVE_DURATION_MS - WAVE_PULSE_MS));
        waveStartTime = millis();
        waveActive = true;
        waveReBroadcastDone = false;
    }
    if (rx.mode == SYNC_MODE_BEAT && rx.virusID != activeBeatID) {
        activeBeatID = rx.virusID;
        beatStartTime = millis();
        beatActive = true;
    }
    if (rx.mode == SYNC_MODE_ZONE && rx.virusID != activeZoneID) {
        activeZoneID = rx.virusID;
        zoneStartTime = millis();
        zoneActive = true;
    }
    if (rx.mode == SYNC_MODE_AMBIENT && rx.virusID != activeAmbientID) {
        activeAmbientID = rx.virusID;
        ambientStartTime = millis();
        ambientActive = true;
        ambientR = (rx.beatCounter >> 16) & 0xFF;
        ambientG = (rx.beatCounter >> 8) & 0xFF;
        ambientB = rx.beatCounter & 0xFF;
    }
    if (rx.mode == SYNC_MODE_STROBE && rx.virusID != activeStrobeID) {
        activeStrobeID = rx.virusID;
        strobeStartTime = millis();
        strobeActive = true;
    }
}

void setup() {
#if ENABLE_SERIAL_DEBUG
    Serial.begin(115200);
    printFwVersionBanner();
#endif
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    
    WiFi.mode(WIFI_STA);
    esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
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

    // 1. MORSE ERKENNUNG
    bool btn = (digitalRead(BUTTON_PIN) == LOW);
    if (btn && btnDownTime == 0) btnDownTime = now;
    if (!btn && btnDownTime != 0) {
        uint32_t duration = now - btnDownTime;
        morseInput += (duration > 250) ? "-" : ".";
#if ENABLE_SERIAL_DEBUG
        Serial.printf("[Morse] +%s (%lu ms) Puffer: \"%s\"\n",
                      (duration > 250) ? "-" : ".", (unsigned long)duration, morseInput.c_str());
#endif
        btnDownTime = 0;
        lastBtnRelease = now;
    }
    if (morseInput.length() > 0 && (now - lastBtnRelease > 800)) {
        if (morseInput == "-.-.") { 
            activeVirusID = random(1, 100000); 
            virusStartTime = now;
#if ENABLE_SERIAL_DEBUG
            Serial.println("[Morse] Wortende -> VIRUS (-.-.)");
#endif
        }
#if ENABLE_SERIAL_DEBUG
        else {
            Serial.printf("[Morse] Wortende -> ignoriert (\"%s\")\n", morseInput.c_str());
        }
#endif
        morseInput = ""; 
    }

    // 2. PEER COUNT & TIMEOUT CLEANUP
    uniquePeerCount = 0;
    for (int i = 0; i < MAX_PEERS; i++) {
        if (seenPeers[i].lastSeen != 0) {
            if (now - seenPeers[i].lastSeen > PEER_TIMEOUT) {
                seenPeers[i].lastSeen = 0;
            } else {
                uniquePeerCount++;
            }
        }
    }

    // 3. DYNAMISCHES FADE-OUT (Der Fix!)
    if (uniquePeerCount == 0) {
        // 2-Sekunden Fade-Out: 50 Einheiten in 100 Frames (bei 20ms) = 0.5 pro Frame
        if (smoothRSSI > -95) smoothRSSI -= 0.5; 
    } else {
        // Minimales Absinken zur Stabilisierung
        smoothRSSI -= 0.01; 
    }
    if (smoothRSSI < -95) smoothRSSI = -95;

    // 4. RSSI MAPPING
    float inputRSSI = constrain(smoothRSSI, -95, -45);
    float norm = (inputRSSI - (-95)) / (-45 - (-95)); 
    float power = norm * norm; 
    uint8_t currentBright = BRIGHT_MIN + (power * (BRIGHT_MAX - BRIGHT_MIN));
    heartBeatState += (2 + (power * 10));

    // 5. ANIMATIONS-WEICHE
    FastLED.clear();
    uint8_t pulse;

    if (now - virusStartTime < 3000) {
        // MORSE / REMOTE VIRUS BLITZ
        uint32_t flash = (now - virusStartTime) % 300;
        if (flash < 150) fill_solid(leds, NUM_LEDS, CRGB::White);
        txData.mode = SYNC_MODE_VIRUS;
        txData.virusID = activeVirusID;
    }
    else if (now - rainbowStartTime < REMOTE_RAINBOW_MS) {
        // REMOTE REGENBOGEN (gleiche Optik wie Singularity)
        hueOffset += 5;
        pulse = beatsin8(100, 150, 255, 0, heartBeatState);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hueOffset + (i*3), 255, pulse);
        txData.mode = SYNC_MODE_RAINBOW;
        txData.virusID = activeRainbowID;
    }
    else if (now - primePartyStartTime < REMOTE_PRIME_MS) {
        // REMOTE PRIMZAHL-PARTY (Optik wie lokale Primzahl-Phase)
        pulse = beatsin8(80, 120, 255, 0, heartBeatState);
        fill_solid(leds, NUM_LEDS, heartColor);
        nscale8(leds, NUM_LEDS, pulse);
        if (random8() > 210) leds[random8(64)] = CRGB::White;
        txData.mode = SYNC_MODE_PRIME;
        txData.virusID = activePrimeID;
    }
    else if (waveActive && (now - waveStartTime < WAVE_DURATION_MS)) {
        // WAVE: ripple von Basisstation, RSSI-basierte Verzögerung
        uint32_t elapsed = now - waveStartTime;
        if (elapsed >= waveDelay && elapsed < waveDelay + WAVE_PULSE_MS) {
            uint32_t pulseElapsed = elapsed - waveDelay;
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
        txData.mode = SYNC_MODE_WAVE;
        txData.virusID = activeWaveID;
        if (!waveReBroadcastDone && elapsed >= waveDelay) {
            waveReBroadcastDone = true;
            delay(random(5, 25));
            esp_now_send(broadcastMac, (uint8_t *)&txData, sizeof(txData));
        }
    }
    else if (beatActive && (now - beatStartTime < BEAT_PULSE_MS)) {
        // BEAT: schneller weisser Puls (150 ms)
        uint32_t elapsed = now - beatStartTime;
        uint8_t brightness;
        if (elapsed < BEAT_PULSE_MS / 2) {
            brightness = (uint8_t)((elapsed * 255) / (BEAT_PULSE_MS / 2));
        } else {
            brightness = (uint8_t)(((BEAT_PULSE_MS - elapsed) * 255) / (BEAT_PULSE_MS / 2));
        }
        fill_solid(leds, NUM_LEDS, CRGB::White);
        nscale8(leds, NUM_LEDS, brightness);
        txData.mode = SYNC_MODE_BEAT;
        txData.virusID = activeBeatID;
    }
    else if (zoneActive && (now - zoneStartTime < REMOTE_ZONE_MS)) {
        // ZONE: RSSI-basierte Farbauswahl (Thresholds: -55, -75)
        CRGB zoneColor;
        if (smoothRSSI > -55) zoneColor = ZONE0_COLOR;
        else if (smoothRSSI > -75) zoneColor = ZONE1_COLOR;
        else zoneColor = ZONE2_COLOR;
        pulse = beatsin8(60, 150, 255, 0, heartBeatState);
        fill_solid(leds, NUM_LEDS, zoneColor);
        nscale8(leds, NUM_LEDS, pulse);
        txData.mode = SYNC_MODE_ZONE;
        txData.virusID = activeZoneID;
    }
    else if (ambientActive && (now - ambientStartTime < REMOTE_AMBIENT_MS)) {
        // AMBIENT: Feste Farbe (RGB aus beatCounter encodet)
        fill_solid(leds, NUM_LEDS, CRGB(ambientR, ambientG, ambientB));
        txData.mode = SYNC_MODE_AMBIENT;
        txData.virusID = activeAmbientID;
    }
    else if (strobeActive && (now - strobeStartTime < STROBE_DURATION_MS)) {
        // STROBE: schnelle weisse Blitze (80 ms on/off, 2 s)
        uint32_t elapsed = now - strobeStartTime;
        if ((elapsed / STROBE_FLASH_MS) % 2 == 0) {
            fill_solid(leds, NUM_LEDS, CRGB::White);
        }
        txData.mode = SYNC_MODE_STROBE;
        txData.virusID = activeStrobeID;
    }
    else if (uniquePeerCount + 1 >= 17) {
        // THE SINGULARITY (≥17 Geräte total: du + sichtbare Peers)
        hueOffset += 5;
        pulse = beatsin8(100, 150, 255, 0, heartBeatState);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hueOffset + (i*3), 255, pulse);
        txData.mode = 0;
    }
    else {
        waveActive = false;
        beatActive = false;
        zoneActive = false;
        ambientActive = false;
        strobeActive = false;
        // NORMAL / PRIME (Gesamtzahl = gefundene Peers + dieses Gerät)
        uint8_t totalDevices = uniquePeerCount + 1;
        bool prime = isPrime(totalDevices);
        pulse = prime ? beatsin8(80, 120, 255, 0, heartBeatState) : beatsin8(35 + (power*55), 100, 255, 0, heartBeatState);

        fill_solid(leds, NUM_LEDS, heartColor);
        nscale8(leds, NUM_LEDS, pulse);

        if (prime && random8() > 210) leds[random8(64)] = CRGB::White;
        txData.mode = 0;
    }

    // Maske: Alles löschen, was nicht zum Herz gehört
    for (int i = 0; i < 64; i++) {
        if (heartMask[i / 8][i % 8] == 0) leds[i] = CRGB::Black;
    }

    // 6. SENDEN
    txData.magic_id = MAGIC_ID;
    txData.beatCounter = heartBeatState;
    txData.ver_major = FW_VERSION_MAJOR;
    txData.ver_minor = FW_VERSION_MINOR;
#if ENABLE_SERIAL_DEBUG
    txData.ver_rel = FW_VERSION_PATCH;
    txData.ver_dbg = FW_DEBUG_BUILD;
#else
    txData.ver_rel = FW_VERSION_PATCH;
    txData.ver_dbg = 0;
#endif
    esp_now_send(broadcastMac, (uint8_t *) &txData, sizeof(txData));

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
                         uniquePeerCount, smoothRSSI, currentBright, morseInput.c_str());
        int listed = 0;
        for (int i = 0; i < MAX_PEERS && n < (int)sizeof(line) - 12 && listed < 10; i++) {
            if (seenPeers[i].lastSeen == 0) continue;
            if (seenPeers[i].ver_known) {
                if (seenPeers[i].ver_dbg) {
                    n += snprintf(line + n, sizeof(line) - (size_t)n, " %u.%u.%02u+",
                                  seenPeers[i].ver_major, seenPeers[i].ver_minor, seenPeers[i].ver_dbg);
                } else {
                    n += snprintf(line + n, sizeof(line) - (size_t)n, " %u.%u.%u",
                                  seenPeers[i].ver_major, seenPeers[i].ver_minor, seenPeers[i].ver_rel);
                }
            } else {
                n += snprintf(line + n, sizeof(line) - (size_t)n, " ?");
            }
            listed++;
        }
        Serial.println(line);
    }
#endif

    delay(20); // ~50 FPS
}