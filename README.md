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

### Build, flash & serial monitor (Arduino CLI)
- **FQBN:** `esp32:esp32:esp32s3` — sketch folder = repository root (`Herz_Schwarm_CCC_V.ino`). Port: `arduino-cli board list`.
- **Production build:** `compile` + `upload` without debug flags (smaller binary, no serial overhead in the loop).
- **Serial debug on USB (ESP32-S3):** enable **USB CDC On Boot** (`CDCOnBoot=cdc`) and `ENABLE_SERIAL_DEBUG=1`. Because `upload` has no `--build-property`, use `--build-path build_debug` on compile and `--input-dir build_debug` on upload — see the **Arduino CLI** subsection under *Setup & Configuration* for copy-paste commands.
- **Live log:** `arduino-cli monitor -p <port> -c baudrate=115200` in an **interactive** terminal; stop with `Ctrl+C` before flashing again.
- **Morse logging:** with debug on, each symbol prints as `[Morse]`; after 800 ms without a new symbol the word is evaluated (`-.-.` triggers the virus, otherwise `ignoriert`). With debug off, none of this is compiled into `loop()`.
- **Firmware version:** see *Firmware-Version* (German section under *Setup & Configuration*): `FW_*` in `Herz_Schwarm_CCC_V.ino`; release `MAJOR.MINOR.PATCH`, debug `MAJOR.MINOR.DD+debug` with `DD` 01–99.

---

## 🛠 Setup & Configuration
- **MCU:** Waveshare ESP32-S3-Matrix
- **Arduino IDE Board:** "ESP32S3 Dev Module"
- **USB Mode:** "Hardware CDC and JTAG"
- **USB CDC On Boot:** *Enabled* if you want `Serial` output on the USB cable while debugging (matches `CDCOnBoot=cdc` in CLI).
- **Library:** FastLED (v3.6+), WiFi, ESP-NOW

### Arduino CLI
Build und Upload lassen sich mit der **Arduino CLI** erledigen. **FQBN:** `esp32:esp32:esp32s3`. **Sketch-Verzeichnis:** Wurzel dieses Repos (Datei `Herz_Schwarm_CCC_V.ino`). Im Ordner `.cursor/rules/` liegt eine **Cursor-Regel** (`arduino-cli.mdc`) mit typischen Befehlen.

**Port ermitteln:**

```bash
arduino-cli board list
```

**Standard-Build & Upload** (ohne Serial-Debug, weniger Flash/RAM):

```bash
arduino-cli compile --fqbn esp32:esp32:esp32s3 .
arduino-cli upload -p /dev/cu.usbmodemXXXX --fqbn esp32:esp32:esp32s3 .
```

(`usbmodemXXXX` durch den eigenen Eintrag aus `board list` ersetzen.)

**Serial-Debug & Live-Log am USB-Kabel (ESP32-S3):**  
Am Rechner erscheint `Serial` nur zuverlässig über USB, wenn **USB CDC On Boot** aktiv ist. Zusätzlich muss `ENABLE_SERIAL_DEBUG` an sein (siehe unten). `arduino-cli upload` unterstützt **kein** `--build-property`; deshalb zuerst in einen Build-Ordner kompilieren und mit `--input-dir` flashen:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32s3 --board-options CDCOnBoot=cdc \
  --build-property "compiler.cpp.extra_flags=-DENABLE_SERIAL_DEBUG=1" \
  --build-path build_debug .
arduino-cli upload -p /dev/cu.usbmodemXXXX --fqbn esp32:esp32:esp32s3 \
  --board-options CDCOnBoot=cdc --input-dir build_debug .
```

Der Zwischenordner `build_debug/` steht in `.gitignore` und wird nicht ins Repo committet.

**Seriellen Monitor (live):** In einem **normalen Terminal** starten (Hintergrund/CI beendet den Monitor oft sofort). **Baudrate:** 115200.

```bash
arduino-cli monitor -p /dev/cu.usbmodemXXXX -c baudrate=115200
```

Beenden mit `Ctrl+C`. Vor einem erneuten Upload den Monitor beenden (Port freigeben).

### Serial-Debug & Morse-Logging
- **Aktivierung:** Im Sketch `ENABLE_SERIAL_DEBUG` auf `1` setzen *oder* beim Kompilieren `-DENABLE_SERIAL_DEBUG=1` wie oben.
- **Aus:** Standard im Sketch ist `0` — dann gibt es **keinen** Serial-Code in der Hauptschleife (kein Einfluss auf die Animation).
- **Mit Debug an:** Es erscheinen u. a. alle 2 s eine **Status**-Zeile (Peers, RSSI, Helligkeit, Morse-Puffer) und **sofort** bei jedem erkannten Morse-Zeichen eine Zeile `[Morse]` mit Dauer in ms; nach 800 ms Pause wird das Wort ausgewertet (`VIRUS` bei exakt `-.-.`, sonst `ignoriert`).
- **Morse-Regel im Code:** Taste gedrückt halten **≤ 250 ms** → Punkt `.`, **> 250 ms** → Strich `-`. Nach **800 ms** ohne neues Zeichen wird der Puffer geleert und geprüft.

### Firmware-Version
Im Sketch `Herz_Schwarm_CCC_V.ino` oben bei den `FW_*`-Defines.

**Git-Stand:** Es gibt noch keine Git-Tags. Die Basis **`1.0.0`** (`FW_VERSION_MAJOR/MINOR/PATCH`) bezeichnet den dokumentierten **Release-Stand** (ESP-NOW-Schwarm, Primzahl/Singularität, Morse-Virus, FastLED/Waveshare) entsprechend der bisherigen Historie (**Merge** Debug→main, Primzahl-Logik, README/CLI).

| Build | Anzeige (Beispiel) | Bedeutung |
|--------|-------------------|-----------|
| **Release** (`ENABLE_SERIAL_DEBUG=0`) | `1.0.0` | Nur `FW_VERSION_*`; kein Serial-Overhead. |
| **Debug** (`ENABLE_SERIAL_DEBUG=1`) | `1.0.01+debug` | `FW_VERSION_MAJOR.MINOR` + **`FW_DEBUG_BUILD`** zweistellig (`01`…`99`) + Kennzeichnung `+debug`. |

**Pflege:**
- **`FW_VERSION_PATCH`** (und bei Bedarf MINOR/MAJOR) bei **Releases / Merge nach `main`** anheben (SemVer-üblich).
- **`FW_DEBUG_BUILD`** nur auf dem **Debug-Zweig** bei jedem **sichtbaren neuen Debug-Stand** um 1 erhöhen, **höchstens 99**. Bei Überlauf: MINOR anheben und Debug-Zähler wieder bei `01` starten (oder neue Basis-Version festlegen — im Team einheitlich halten).
- Nach größeren Änderungen: Kurzkommentar im Sketch neben den `FW_*`-Zeilen aktualisieren.

### Code Adjustments
Ensure the FastLED initialization matches the Waveshare hardware (im Sketch ist die Farbreihenfolge wie dort verdrahtet gesetzt, siehe `Herz_Schwarm_CCC_V.ino`):
`FastLED.addLeds<WS2812B, 14, BGR>(leds, 64);`

---
**Happy Hacking!** 🚀✨
