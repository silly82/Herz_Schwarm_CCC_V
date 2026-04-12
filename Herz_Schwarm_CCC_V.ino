#include <esp_now.h>
#include <WiFi.h>
#include <FastLED.h>
#include <esp_wifi.h>

// --- HARDWARE ---
#define LED_PIN     14
#define NUM_LEDS    64
#define BUTTON_PIN  0    
#define BRIGHT_MIN  4   
#define BRIGHT_MAX  160 

// --- CCC SETTINGS ---
#define CCC_CHANNEL 13          
#define MAGIC_ID    0x421337CC  
#define PEER_TIMEOUT 8000       
#define MAX_PEERS   25          

// --- DATENSTRUKTUR ---
struct SyncPacket {
    uint32_t magic_id;    
    uint32_t beatCounter; 
    uint32_t virusID;    
    uint8_t  mode;       
};

// --- MASKE (Muss oben stehen!) ---
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

// --- MORSE VARIABLEN ---
uint32_t btnDownTime = 0;
String morseInput = "";
uint32_t lastBtnRelease = 0;

CRGB heartColor = CRGB(255, 0, 150); 

// --- HELPER ---
bool isPrime(int n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (int i = 5; i * i <= n; i += 6) if (n % i == 0 || n % (i + 2) == 0) return false;
    return true;
}

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
            smoothRSSI = (0.04 * (float)recv_info->rx_ctrl->rssi) + (0.96 * smoothRSSI);
            heartBeatState = rx->beatCounter;
            if (rx->mode == 1 && rx->virusID != activeVirusID) {
                activeVirusID = rx->virusID;
                virusStartTime = millis();
            }
        }
    }
}

void setup() {
    Serial.begin(115200);
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

    FastLED.addLeds<WS2812B, LED_PIN, RGB>(leds, NUM_LEDS);
}

void loop() {
    uint32_t now = millis();

    // 1. MORSE
    bool btn = (digitalRead(BUTTON_PIN) == LOW);
    if (btn && btnDownTime == 0) btnDownTime = now;
    if (!btn && btnDownTime != 0) {
        uint32_t duration = now - btnDownTime;
        morseInput += (duration > 250) ? "-" : ".";
        btnDownTime = 0;
        lastBtnRelease = now;
    }
    if (morseInput.length() > 0 && (now - lastBtnRelease > 1000)) {
        if (morseInput == "-.-.") { 
            activeVirusID = random(1, 100000); 
            virusStartTime = now;
        }
        morseInput = ""; 
    }

    // 2. PEERS
    uniquePeerCount = 0;
    for (int i = 0; i < MAX_PEERS; i++) {
        if (seenPeers[i].lastSeen != 0) {
            if (now - seenPeers[i].lastSeen > PEER_TIMEOUT) seenPeers[i].lastSeen = 0;
            else uniquePeerCount++;
        }
    }

    // 3. LOGIK
    float inputRSSI = constrain(smoothRSSI, -95, -45);
    float norm = (inputRSSI - (-95)) / (-45 - (-95)); 
    float power = norm * norm; 
    uint8_t currentBright = BRIGHT_MIN + (power * (BRIGHT_MAX - BRIGHT_MIN));
    heartBeatState += (2 + (power * 10));

    FastLED.clear();
    uint8_t pulse;

    if (now - virusStartTime < 3000) {
        uint32_t flash = (now - virusStartTime) % 400;
        if (flash < 200) fill_solid(leds, NUM_LEDS, CRGB::White);
        txData.mode = 1;
        txData.virusID = activeVirusID;
    } 
    else if (uniquePeerCount >= 17) {
        hueOffset += 5;
        pulse = beatsin8(100, 150, 255, 0, heartBeatState);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hueOffset + (i*3), 255, pulse);
        txData.mode = 0;
    } 
    else {
        pulse = isPrime(uniquePeerCount) ? beatsin8(80, 100, 255, 0, heartBeatState) : beatsin8(35 + (power*55), 100, 255, 0, heartBeatState);
        fill_solid(leds, NUM_LEDS, CRGB(255, 0, 150));
        nscale8(leds, NUM_LEDS, pulse);
        if(isPrime(uniquePeerCount) && random8() > 210) leds[random8(64)] = CRGB::White;
        txData.mode = 0;
    }

    // Herz-Maske anwenden
    for (int i = 0; i < 64; i++) {
        if (heartMask[i / 8][i % 8] == 0) leds[i] = CRGB::Black;
    }

    // 4. SENDEN
    txData.magic_id = MAGIC_ID;
    txData.beatCounter = heartBeatState;
    esp_now_send(broadcastMac, (uint8_t *) &txData, sizeof(txData));

    // 5. OUTPUT
    FastLED.setBrightness(currentBright);
    smoothRSSI -= 0.005; 
    if (smoothRSSI < -95) smoothRSSI = -95;
    FastLED.show();
    delay(20);
}