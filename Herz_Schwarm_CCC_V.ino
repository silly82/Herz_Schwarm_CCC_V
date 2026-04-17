#include <esp_now.h>
#include <WiFi.h>
#include <FastLED.h>
#include <esp_wifi.h>

// Serial-Ausgaben blockieren und können die Animation ruckeln lassen — Standard: aus.
// Aktivieren: hier auf 1 setzen oder Build-Flag: -DENABLE_SERIAL_DEBUG=1
#ifndef ENABLE_SERIAL_DEBUG
#define ENABLE_SERIAL_DEBUG 0
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

// --- DATENSTRUKTUR ---
struct SyncPacket {
    uint32_t magic_id;    
    uint32_t beatCounter; 
    uint32_t virusID;    
    uint8_t  mode;       
};

// --- MASKE (Oben definiert für den Compiler) ---
const uint8_t heartMask[8][8] = {
  {0,0,0,0,0,0,0,0}, {0,1,1,0,0,1,1,0}, {1,1,1,1,1,1,1,1}, {1,1,1,1,1,1,1,1},
  {1,1,1,1,1,1,1,1}, {0,1,1,1,1,1,1,0}, {0,0,1,1,1,1,0,0}, {0,0,0,1,1,0,0,0}
};

SyncPacket txData;
CRGB leds[NUM_LEDS];

// --- PEER TRACKING ---
struct PeerTracker { uint8_t mac[6]; uint32_t lastSeen; };
PeerTracker seenPeers[MAX_PEERS];
uint8_t uniquePeerCount = 0;

// --- VARIABLEN ---
float smoothRSSI = -95;   
uint32_t heartBeatState = 0; 
uint8_t hueOffset = 0;
uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
uint32_t activeVirusID = 0;
uint32_t virusStartTime = 0;

// Morse Variablen
uint32_t btnDownTime = 0;
String morseInput = "";
uint32_t lastBtnRelease = 0;

CRGB heartColor = CRGB(255, 0, 150); // Cyber-Pink

// --- HELPER: PRIMZAHL ---
bool isPrime(int n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (int i = 5; i * i <= n; i += 6) if (n % i == 0 || n % (i + 2) == 0) return false;
    return true;
}

// --- PEER TRACKING LOGIK ---
void trackBadge(const uint8_t* mac) {
    uint32_t now = millis();
    for (int i = 0; i < MAX_PEERS; i++) {
        if (memcmp(seenPeers[i].mac, mac, 6) == 0) { seenPeers[i].lastSeen = now; return; }
    }
    for (int i = 0; i < MAX_PEERS; i++) {
        if (seenPeers[i].lastSeen == 0) { memcpy(seenPeers[i].mac, mac, 6); seenPeers[i].lastSeen = now; return; }
    }
}

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
    if (len == sizeof(SyncPacket)) {
        SyncPacket* rx = (SyncPacket*)incomingData;
        if (rx->magic_id == MAGIC_ID) {
            trackBadge(recv_info->src_addr);
            // Empfangenes Signal gewichten
            float currentRSSI = (float)recv_info->rx_ctrl->rssi;
            smoothRSSI = (0.05 * currentRSSI) + (0.95 * smoothRSSI);
            heartBeatState = rx->beatCounter;
            
            if (rx->mode == 1 && rx->virusID != activeVirusID) {
                activeVirusID = rx->virusID;
                virusStartTime = millis();
            }
        }
    }
}

void setup() {
#if ENABLE_SERIAL_DEBUG
    Serial.begin(115200);
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
        btnDownTime = 0;
        lastBtnRelease = now;
    }
    if (morseInput.length() > 0 && (now - lastBtnRelease > 800)) {
        if (morseInput == "-.-.") { 
            activeVirusID = random(1, 100000); 
            virusStartTime = now;
        }
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
        // MORSE VIRUS BLITZ
        uint32_t flash = (now - virusStartTime) % 300;
        if (flash < 150) fill_solid(leds, NUM_LEDS, CRGB::White);
        txData.mode = 1;
        txData.virusID = activeVirusID;
    } 
    else if (uniquePeerCount + 1 >= 17) {
        // THE SINGULARITY (≥17 Geräte total: du + sichtbare Peers)
        hueOffset += 5;
        pulse = beatsin8(100, 150, 255, 0, heartBeatState);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hueOffset + (i*3), 255, pulse);
        txData.mode = 0;
    } 
    else {
        // NORMAL / PRIME (Gesamtzahl = gefundene Peers + dieses Gerät)
        uint8_t totalDevices = uniquePeerCount + 1;
        bool prime = isPrime(totalDevices);
        pulse = prime ? beatsin8(80, 120, 255, 0, heartBeatState) : beatsin8(35 + (power*55), 100, 255, 0, heartBeatState);
        
        fill_solid(leds, NUM_LEDS, heartColor);
        nscale8(leds, NUM_LEDS, pulse);
        
        if(prime && random8() > 210) leds[random8(64)] = CRGB::White;
        txData.mode = 0;
    }

    // Maske: Alles löschen, was nicht zum Herz gehört
    for (int i = 0; i < 64; i++) {
        if (heartMask[i / 8][i % 8] == 0) leds[i] = CRGB::Black;
    }

    // 6. SENDEN
    txData.magic_id = MAGIC_ID;
    txData.beatCounter = heartBeatState;
    esp_now_send(broadcastMac, (uint8_t *) &txData, sizeof(txData));

    // 7. OUTPUT
    FastLED.setBrightness(currentBright);
    FastLED.show();

#if ENABLE_SERIAL_DEBUG
    // Debug Info (nur alle 2 Sek) — bei ausgeschaltetem Flag kein Serial-Overhead in der Schleife
    if (now % 2000 < 20) {
        Serial.printf("Peers: %d | RSSI: %.1f | Bright: %d | In: %s\n",
                      uniquePeerCount, smoothRSSI, currentBright, morseInput.c_str());
    }
#endif

    delay(20); // ~50 FPS
}