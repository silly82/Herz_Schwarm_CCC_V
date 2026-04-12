# ❤️ CCC Heart Swarm Badge (Herz-Schwarm)

Synchronized ESP-NOW Heart Badges for the CCC Camp & Congress.
*Synchronisierte ESP-NOW Herz-Badges für das CCC Camp & den Congress.*

---

## 🇩🇪 Schweizer Hochdeutsch

### Was ist das?
Ein Schwarm von 8x8 LED Herz-Badges auf Basis der **Waveshare ESP32-S3-Matrix**. Die Badges kommunizieren über **ESP-NOW**, synchronisieren ihren Takt, reagieren auf die Nähe anderer Geräte (RSSI) und enthalten interaktive Easter Eggs.

### Funktionen
- **Herzschlag-Sync:** Alle Badges schlagen im exakt gleichen Rhythmus.
- **Näherungseffekt:** Je näher du anderen kommst, desto heller und schneller pulsiert dein Herz.
- **Primzahlen-Osterei:** Bei einer Primzahl an Badges (2, 3, 5, 7...) glitzern die Herzen weiss.
- **Die Singularität (17 Badges):** Bei exakt 17 Badges wird ein **Regenbogen-Blitz** ausgelöst.
- **Der Morse-Virus:** Morsese ein **«C»** (`- . - .`) über die BOOT-Taste, um einen weissen Blitz-Virus durch den gesamten Schwarm zu jagen.

### Spezifische Hardware-Hinweise (Waveshare ESP32-S3-Matrix)
- **Pinout:** Die interne Matrix ist fest an **GPIO 14** verdrahtet. Die BOOT-Taste liegt auf **GPIO 0**.
- **Farben:** Die verbauten LEDs nutzen die Reihenfolge **GRB** (bitte im Code anpassen).
- **Sicherheit:** Da die Rückseite des Boards offene Kontakte hat, wird dringend empfohlen, diese mit Klebeband (Kapton) zu isolieren oder ein Gehäuse zu verwenden.

---

## 🇬🇧 English

### What is this?
A swarm of 8x8 LED heart badges based on the **Waveshare ESP32-S3-Matrix**. They communicate via **ESP-NOW**, sync their pulse, react to proximity (RSSI), and feature interactive Easter Eggs.

### Features
- **Heartbeat Sync:** All badges beat at the exact same rhythm.
- **Proximity Awareness:** Proximity increases brightness and pulse speed.
- **Prime Number Easter Egg:** Hearts sparkle white when a prime number of badges (2, 3, 5, 7...) is present.
- **The Singularity (17 Badges):** Exactly 17 badges trigger a full **Rainbow Blitz**.
- **The Morse Virus:** Morse a **"C"** (`- . - .`) using the BOOT button to trigger a white flash "virus" across the entire swarm.

### Specific Hardware Notes (Waveshare ESP32-S3-Matrix)
- **Pinout:** Internal matrix is wired to **GPIO 14**. BOOT button is on **GPIO 0**.
- **Color Order:** The LEDs use **GRB** order (ensure this is set in the code).
- **Safety:** As the back of the board has exposed contacts, it is highly recommended to insulate it with tape (Kapton) or use a 3D-printed case.

---

## 🛠 Setup & Configuration
- **MCU:** Waveshare ESP32-S3-Matrix
- **Arduino IDE Board:** "ESP32S3 Dev Module"
- **USB Mode:** "Hardware CDC and JTAG"
- **Library:** FastLED (v3.6+), WiFi, ESP-NOW

### Code Adjustments
Ensure the FastLED initialization matches the Waveshare hardware:
`FastLED.addLeds<WS2812B, 14, GRB>(leds, 64);`

---
**Happy Hacking!** 🚀✨
