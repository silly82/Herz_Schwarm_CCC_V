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
- **Die Welle (Basisstation):** Eine Welle breitet sich von der Basisstation aus: Badges in der Nähe leuchten zuerst, weiter entfernte später (RSSI-basierte Verzögerung, ~4 s Gesamtdauer). Badges leiten die Welle per ESP-NOW weiter.
- **Fernauslösung (Basisstation):** Kompatibles `SyncPacket` mit `mode` **1** (Virus), **2** (Regenbogen / Singularity-Optik ~15 s), **3** (Primzahl-Party ~12 s), **4** (Welle / RSSI-Ripple ~4 s), **5** (Beat-Puls ~150 ms), **6** (RSSI-Zonen-Farben ~5 s), **7** (Ambient-Farbe ~30 s), **8** (Strobe ~2 s). Neue `virusID` pro Effekt verhindert Doppel-Trigger; während eines Effekts wird der passende `mode` weitergesendet (Kettenreaktion im Schwarm).
- **Nerves-Controller (Raspberry Pi):** Optionale Elixir/Nerves-App (`herz_schwarm_nerves/`) steuert den Schwarm über einen USB-ESP32-Bridge (ESP-NOW). LiveView Web-UI für Effekt-Steuerung, Beat-Tap-Tempo, Ambient-Farbwahl. Koexistiert mit der Basisstation auf Kanal 13.

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
- **The Wave (base station):** A wave ripples outward from the base station: nearby badges light up first, distant ones later (RSSI-based delay, ~4 s total). Badges re-broadcast the wave via ESP-NOW for swarm propagation.
- **Remote trigger (base station):** Compatible `SyncPacket` with `mode` **1** (virus), **2** (rainbow / singularity look ~15 s), **3** (prime-party look ~12 s), **4** (wave / RSSI ripple ~4 s), **5** (beat pulse ~150 ms), **6** (RSSI zone colors ~5 s), **7** (ambient color ~30 s), **8** (strobe ~2 s). A fresh `virusID` per effect avoids re-triggering; while active, badges forward the same `mode` for swarm propagation.
- **Nerves Controller (Raspberry Pi):** Optional Elixir/Nerves app (`herz_schwarm_nerves/`) controls the swarm via a USB ESP32 bridge (ESP-NOW). LiveView web-UI for effect control, beat tap-tempo, ambient color picker. Coexists with the base station on channel 13.

### Specific Hardware Notes (Waveshare ESP32-S3-Matrix)
- **Pinout:** Internal matrix is wired to **GPIO 14**. BOOT button is on **GPIO 0**.
- **Color Order:** The LEDs use **GRB** order (ensure this is set in the code).
- **Safety:** As the back of the board has exposed contacts, it is highly recommended to insulate it with tape (Kapton) or use a 3D-printed case.

### Build, flash & serial monitor (Arduino CLI)
- **FQBN:** `esp32:esp32:esp32s3` — sketch folder = repository root (`Herz_Schwarm_CCC_V.ino`). Port: `arduino-cli board list`.
- **Production build:** `compile` + `upload` without debug flags (smaller binary, no serial overhead in the loop).
- **Serial debug on USB (ESP32-S3):** enable **USB CDC On Boot** (`CDCOnBoot=cdc`) and `ENABLE_SERIAL_DEBUG=1`. Because `upload` has no `--build-property`, use `--build-path build_debug` on compile and `--input-dir build_debug` on upload — see the **Arduino CLI** subsection under *Setup & Configuration* for copy-paste commands.
- **Live log:** `arduino-cli monitor -p <port> -c baudrate=115200` in an **interactive** terminal; stop with `Ctrl+C` before flashing again.
- **Batch flash (several devices):** `scripts/batch_flash_herz_schwarm.sh` needs **esptool** on `PATH` in addition to arduino-cli. See *Batch-Update* under *Setup & Configuration* (German) for options and the log files `firmware_update_log.csv` / `firmware_update_log.md`.
- **Morse logging:** with debug on, each symbol prints as `[Morse]`; after 800 ms without a new symbol the word is evaluated (`-.-.` triggers the virus, otherwise `ignoriert`). With debug off, none of this is compiled into `loop()`.
- **Firmware version:** see *Firmware-Version* (German section under *Setup & Configuration*): `FW_*` in `Herz_Schwarm_CCC_V.ino`; release `MAJOR.MINOR.PATCH`, debug `MAJOR.MINOR.DD+debug` with `DD` 01–99.
- **ESP-NOW:** firmware version is sent in each sync packet (17-byte `SyncPacket`); legacy13-byte peers still work — see *ESP-NOW Paket (Sync)* in the German section.

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

### Batch-Update (mehrere Badges nacheinander)

Für viele Waveshare-Matrix-Badges am USB (nacheinander flashen oder **mehrere USB-Ports gleichzeitig**): Skript `scripts/batch_flash_herz_schwarm.sh` im Repo. Es baut **einmal** in den lokalen Ordner `build_batch/` (in `.gitignore`, analog zu `build_debug/`) und führt pro erkanntem Port `arduino-cli upload` aus, danach **`esptool read_mac`**, und **hängt** einen Eintrag an die Protokolldateien in der **Repo-Wurzel** an:

- **`firmware_update_log.csv`** — Semikolon-getrennt: Zeitstempel, Firmware-String, Port, Ergebnis, MAC
- **`firmware_update_log.md`** — dieselben Daten als Markdown-Tabelle

**Voraussetzung:** [Arduino CLI](https://arduino.github.io/arduino-cli/) (wie oben) **und** [esptool](https://github.com/espressif/esptool) (`esptool.py` oder `esptool` im `PATH`, z. B. `brew install esptool`). Liest esptool den Chip nicht, **`ESPTOOL=/pfad/zu/esptool.py`** setzen.

**Port-Erkennung:** `arduino-cli board list --format json` — es werden Anschlüsse genutzt, deren **Board-Erkennung** `esp32:esp32:esp32s3` *oder* (häufig auf macOS) **`esp32:esp32:esp32_family`** liefert. Wenn kein passender Port erscheint, Ports manuell oder per USB-Heuristik:

```bash
chmod +x scripts/batch_flash_herz_schwarm.sh
./scripts/batch_flash_herz_schwarm.sh
./scripts/batch_flash_herz_schwarm.sh --ports /dev/cu.usbmodem101 /dev/cu.usbmodem102
./scripts/batch_flash_herz_schwarm.sh --all-usb
./scripts/batch_flash_herz_schwarm.sh --no-compile
./scripts/batch_flash_herz_schwarm.sh --debug
```

| Option / Ablauf | Bedeutung |
|-----------------|-----------|
| (ohne Optionen) | Erkannte ESP32-Ports flashen, einmal kompilieren |
| `--ports …` | Nur diese Gerätepfade (z. B. aus `arduino-cli board list`) |
| `--all-usb` | Typische USB-Seriell-Pfade (`usbmodem*`, WCH, FTDI-ähnlich), wenn die CLI kein FQBN meldet |
| `--no-compile` | Nur `upload` aus bestehendem `build_batch/` (nach vorherigem Lauf) |
| `--debug` | Entspricht **Serial-Debug**-Build: `CDCOnBoot=cdc` und `-DENABLE_SERIAL_DEBUG=1` (siehe oben) |

Vor dem Lauf: **seriellen Monitor beenden** (`Ctrl+C`), sonst ist der Port belegt. Pro Gerät: zuerst Flash, danach MAC auslesen; Ergebnis `ok` / `upload_failed` / `ok_mac_unread` u. a. steht in der CSV/MD. Ausdrücklich mit **`bash ./scripts/...`** starten, falls die System-Shell zickt.

### Serial-Debug & Morse-Logging
- **Aktivierung:** Im Sketch `ENABLE_SERIAL_DEBUG` auf `1` setzen *oder* beim Kompilieren `-DENABLE_SERIAL_DEBUG=1` wie oben.
- **Aus:** Standard im Sketch ist `0` — dann gibt es **keinen** Serial-Code in der Hauptschleife (kein Einfluss auf die Animation).
- **Mit Debug an:** Es erscheinen u. a. alle 2 s eine **Status**-Zeile (Peers, RSSI, Helligkeit, Morse-Puffer) und **sofort** bei jedem erkannten Morse-Zeichen eine Zeile `[Morse]` mit Dauer in ms; nach 800 ms Pause wird das Wort ausgewertet (`VIRUS` bei exakt `-.-.`, sonst `ignoriert`).
- **Morse-Regel im Code:** Taste gedrückt halten **≤ 250 ms** → Punkt `.`, **> 250 ms** → Strich `-`. Nach **800 ms** ohne neues Zeichen wird der Puffer geleert und geprüft.

### Firmware-Version
Im Sketch `Herz_Schwarm_CCC_V.ino` oben bei den `FW_*`-Defines.

**Git-Stand:** Annotierter Tag **`v1.0.0`** auf `main` markiert diesen Stand. Die Basis **`1.0.0`** (`FW_VERSION_MAJOR/MINOR/PATCH`) bezeichnet den **Release-Stand** (ESP-NOW-Schwarm, Primzahl/Singularität, Morse-Virus, FastLED/Waveshare).

| Build | Anzeige (Beispiel) | Bedeutung |
|--------|-------------------|-----------|
| **Release** (`ENABLE_SERIAL_DEBUG=0`) | `1.0.0` | Nur `FW_VERSION_*`; kein Serial-Overhead. |
| **Debug** (`ENABLE_SERIAL_DEBUG=1`) | `1.0.01+debug` | `FW_VERSION_MAJOR.MINOR` + **`FW_DEBUG_BUILD`** zweistellig (`01`…`99`) + Kennzeichnung `+debug`. |

**Pflege:**
- **`FW_VERSION_PATCH`** (und bei Bedarf MINOR/MAJOR) bei **Releases / Merge nach `main`** anheben (SemVer-üblich).
- **`FW_DEBUG_BUILD`** nur auf dem **Debug-Zweig** bei jedem **sichtbaren neuen Debug-Stand** um 1 erhöhen, **höchstens 99**. Bei Überlauf: MINOR anheben und Debug-Zähler wieder bei `01` starten (oder neue Basis-Version festlegen — im Team einheitlich halten).
- Nach größeren Änderungen: Kurzkommentar im Sketch neben den `FW_*`-Zeilen aktualisieren.

### ESP-NOW Paket (Sync)
Kompaktes `SyncPacket` (packed): `magic_id`, `beatCounter`, `virusID`, `mode` wie bisher, plus **vier Byte** `ver_major`, `ver_minor`, `ver_rel`, `ver_dbg` (gesamt **17 Byte**). **Ältere Firmware** sendet nur **13 Byte** — wird weiter erkannt; die Version des Peers bleibt dann unbekannt (`?` im Debug-Log), bis ein Paket mit voller Länge ankommt. Zusätzliche Kosten: etwas größeres Payload pro Sendezyklus (weiterhin ein `esp_now_send` pro Frame), wenig RAM pro Peer für die gespeicherte Version.

**`mode`-Werte (Badge & Basisstation):** `0` normal; `1` Virus-Animation; `2` Fern-Regenbogen; `3` Fern-Primzahl-Party; `4` Welle (RSSI-basierter Ripple, ~4 s); `5` Beat-Puls (weiss, ~150 ms); `6` RSSI-Zonen-Farben (rot/gelb/blau, ~5 s); `7` Ambient-Farbe (RGB aus `beatCounter`, ~30 s); `8` Strobe (weisse Blitze, ~2 s). (Nur `1`…`8` lösen Effekte aus; `0` ist Standard nach den Effekt-Fenstern bzw. bei reiner Nähe-Logik.)

---

## Projekt-Dokumentation (nummeriert)

1. **Badge-Sketch:** `Herz_Schwarm_CCC_V.ino` (Repo-Wurzel), Ziel-Hardware **Waveshare ESP32-S3-Matrix**, **FQBN** `esp32:esp32:esp32s3`, Kanal **13**, `MAGIC_ID` wie im Sketch.
2. **Basisstation-Sketch:** Ordner `Herz_Schwarm_BaseStation/`, Datei `Herz_Schwarm_BaseStation.ino`, **FQBN** `esp32:esp32:esp32s3`; Ethernet **W5500** (Referenz-Pins Spotpear: SCK 13, MISO 12, MOSI 11, CS 14, RST 9, INT 10).
3. **Firmware-Version Basisstation:** `STATION_FW_MAJOR/MINOR/PATCH` im Basisstation-Sketch; in der Web-UI und in JSON (`/api/peers` → `station`) sichtbar.
4. **Web-UI Basisstation:** HTTP Port **80** nach Ethernet-IP (`/`): Peers-Tabelle (Polling), Eastereggs (Virus / Regenbogen / Primzahl-Party / Welle), **MQTT-Konfiguration** (Formular).
5. **REST-API Basisstation:** `GET /api/peers` (JSON: Station-Version, Peer-Liste mit MAC, RSSI, Firmware-String, Alter); `POST /api/effect?m=1|2|3|4`; `POST /api/virus` (Alias für `m=1`); `GET /api/mqtt` (Konfiguration **ohne** Passwort, mit `has_password` und `connected`); `POST /api/mqtt` (Form-URL-encoded: `en`, `host`, `port`, `user`, optional `pass`, `ts`, `tc` — leeres Passwort = unverändert). Modi 5–8 werden nur vom Nerves-Controller gesendet (direkt via ESP-NOW-Bridge).
6. **MQTT:** **Klartext-TCP** (typisch Port **1883**), **kein TLS**. Einstellungen in **NVS** (`Preferences`, Namespace `hs_mqtt`); Broker per **Hostname oder IP** (`Network.hostByName`). Topics konfigurierbar: Status (Publish, JSON wie Peers-Kurzform), Befehl (Subscribe → löst Virus/Effekt `m=1` aus).
7. **Kompilieren Basisstation:** `arduino-cli compile --fqbn esp32:esp32:esp32s3 Herz_Schwarm_BaseStation` (Pfad zum Ordner anpassen).
8. **Flashen Badge:** `arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32s3 .` im Repo-Wurzelverzeichnis; Port mit `arduino-cli board list`.
9. **Flashen Basisstation:** `arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32s3 Herz_Schwarm_BaseStation`.
9a. **Batch-Update Badges:** `scripts/batch_flash_herz_schwarm.sh` (siehe Abschnitt *Batch-Update*), Log: `firmware_update_log.csv` / `firmware_update_log.md`, Build-Cache `build_batch/`.
10. **Build-Artefakte:** Ordner `build_debug/`, `build_batch/` und `build_basestation/` sind in `.gitignore` und gehören nicht ins Repository.
11. **Abwärtskompatibilität:** Badges mit alter Firmware reagieren nur auf **`mode == 1`** (Virus); `2`–`8` werden ignoriert. Basisstation und Nerves-Controller können trotzdem alle Modi senden.
12. **Nerves-Controller:** Ordner `herz_schwarm_nerves/`, Elixir/Nerves-App für **Raspberry Pi 4**. Steuert Badges über USB-ESP32-Bridge (ESP-NOW Kanal 13). Web-UI auf Port 4000. Bridge-Firmware: `herz_schwarm_nerves/firmware/esp32_bridge/esp32_bridge.ino` (Arduino, benötigt ArduinoJson-Library). Effektmodi 1–8, Beat-Tap-Tempo, Ambient-RGB-Steuerung. Koexistiert mit Basisstation (unterschiedliche `virusID`s).
13. **Cursor / Arduino CLI:** Zusätzliche Befehle in `.cursor/rules/arduino-cli.mdc`.

### Code Adjustments
Ensure the FastLED initialization matches the Waveshare hardware (im Sketch ist die Farbreihenfolge wie dort verdrahtet gesetzt, siehe `Herz_Schwarm_CCC_V.ino`):
`FastLED.addLeds<WS2812B, 14, BGR>(leds, 64);`

---
**Happy Hacking!** 🚀✨
