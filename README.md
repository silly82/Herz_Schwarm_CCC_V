# ❤️ CCC Heart Swarm Badge (Herz-Schwarm)

Synchronized ESP-NOW Heart Badges for the CCC Camp & Congress.
*Synchronisierte ESP-NOW Herz-Badges für das CCC Camp & den Congress.*

---

## Deutsch

### Was ist das?
Ein Schwarm von 8x8 LED Herz-Badges auf Basis der **Waveshare ESP32-S3-Matrix**. Die Badges kommunizieren über **ESP-NOW**, synchronisieren ihren Takt, reagieren auf die Nähe anderer Geräte (RSSI) und enthalten interaktive Easter Eggs.

### Funktionen
- **Herzschlag-Sync:** Alle Badges schlagen im exakt gleichen Rhythmus.
- **Näherungseffekt:** Je näher du anderen kommst, desto heller und schneller pulsiert dein Herz.
- **Primzahlen-Osterei:** Wenn die **Gesamtzahl im Schwarm** eine Primzahl ist — also **sichtbare andere Badges plus dein eigenes** (z. B. du + 16 andere = 17) — pulsiert das Herz stärker und es gibt weisse Glitzer-Pixel.
- **Die Singularität (≥17 Geräte):** Sobald **mindestens 17 Geräte insgesamt** da sind (du + 16 sichtbare Peers), schaltet die Animation auf den **Regenbogen-Modus** um (nicht nur bei exakt 17).
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
- **Prime Number Easter Egg:** When the **total swarm size** is prime — **other visible badges plus your own** (e.g. you + 16 others = 17) — the heart pulses more strongly with occasional white sparkles.
- **The Singularity (≥17 devices):** When **at least 17 devices** are present in total (you + 16 visible peers), the animation switches to **rainbow mode** (not only at exactly 17).
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

### Arduino CLI
Build und Upload lassen sich mit der **Arduino CLI** erledigen, z. B. FQBN `esp32:esp32:esp32s3` und Sketch-Verzeichnis = dieses Repo. Im Ordner `.cursor/rules/` liegt eine **Cursor-Regel** (`arduino-cli.mdc`) mit typischen Befehlen für dieses Projekt (optional für KI-Unterstützung in Cursor).

### Code Adjustments
Ensure the FastLED initialization matches the Waveshare hardware (im Sketch ist die Farbreihenfolge wie dort verdrahtet gesetzt, siehe `Herz_Schwarm_CCC_V.ino`):
`FastLED.addLeds<WS2812B, 14, BGR>(leds, 64);`

---
**Happy Hacking!** 🚀✨
