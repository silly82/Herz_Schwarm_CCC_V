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
- **Die Welle (Basisstation):** Eine Welle breitet sich von der Basisstation aus: Badges in der Nähe leuchten zuerst, weiter entfernte später. Ein Durchlauf dauert ~4 s und wiederholt sich ab Badge-FW 1.4.1 **endlos** (Zyklus alle 4000 ms) — beendet wird die Welle erst per **manuellem Stopp** (Modus `10`, oder `12` für alle Effekte): Toggle im Web-UI, MQTT-Payload `10` oder Nerves-Dashboard; Badges leiten den Stopp begrenzt weiter, so erreicht er auch Geräte außerhalb der Basis-Reichweite. Ältere Badges verstehen den Stopp nicht und laufen wie bisher nach ~4 s aus. Ab Badge-FW 1.4.0: Wer die Basis direkt hört, zündet nach deren Signal (−45 dBm → sofort, −95 dBm → 2 s); alle anderen nach dem Badge, von dem sie die Welle haben, plus 150–750 ms je nach Signal zu ihm. Jedes Badge rechnet dabei auf den gemeinsamen Wellenstart zurück und übernimmt den kürzesten bekannten Weg — die Welle läuft so auch zu Badges, die die Basis gar nicht hören.
- **Fernauslösung (Basisstation):** Kompatibles `SyncPacket` mit `mode` **1** (Virus), **2** (Regenbogen / Singularity-Optik), **3** (Primzahl-Party), **4** (Welle / RSSI-Ripple, 4-s-Zyklus), **5** (Beat-Puls ~150 ms), **6** (RSSI-Zonen-Farben), **7** (Ambient-Farbe), **8** (Strobe), **10** (Welle stoppen — beendet die laufende Welle, ab Badge-FW 1.4.1), **11** (Tap-Meldung — `virusID` = Tap-Zählerstand), **12** (Alle stoppen — global, `virusID = 0`). Ab Badge-FW **1.5.0** laufen alle visuellen Effekte **endlos**, bis man sie stoppt oder ein neu gestarteter visueller Effekt sie ersetzt („letzter Effekt gewinnt" — Beat und Identify bleiben dabei erhalten). Die früheren festen Fenster (Virus 3 s, Regenbogen 15 s, Primzahl 12 s, Zonen 5 s, Ambient 30 s, Strobe 2 s) sind nur noch **nominale Zykluslängen**, nach denen der Effekt sich wiederholt. Ausnahmen: **Beat** bleibt ein 150-ms-Puls pro Paket, **Identify** (Modus 9) bleibt 10 s. Neue `virusID` pro Effekt verhindert Doppel-Trigger; während eines Effekts wird der passende `mode` weitergesendet (Kettenreaktion im Schwarm).
- **Tap-Counter (BOOT-Taste, ab Badge-FW 1.5.0):** Kurze Drücke auf die BOOT-Taste (**≤ 250 ms** — dieselben Ereignisse, die in der Morse-Eingabe ein Punkt sind; Morse unverändert) werden gezählt und als Modus `11` gemeldet (`virusID` = Zählerstand, monoton; 3× im 60-ms-Abstand plus Nachsendung nach 1,2 s, einmal beim Start). Andere Badges leiten fremde Tap-Pakete begrenzt weiter (**23 Byte** mit angehängter Ursprungs-MAC) und merken sich je MAC den höchsten Stand (Dedup). Der Zählerstand wird gedrosselt in NVS gespeichert (Namespace `hstap`, max. 1 Schreibvorgang/30 s). In der Nerves-App endet die Kette als **Tap-Counter-Karte** (Gesamtsumme und je Badge, Reset mit Rückfrage — Reset setzt nur die Anzeige auf 0, die Badge-Zähler laufen weiter).
- **Alle stoppen (Modus `12`, ab Badge-FW 1.5.0):** Globaler Stopp (`virusID = 0`): Badges deaktivieren alle Effekt-Slots außer Identify und leiten den Stopp begrenzt weiter (max. 3 Sendungen, ~60 ms Abstand, dann 1000 ms Sperre — gleiches Muster wie der Wellen-Stopp). Erreichbar über Dashboard-Knopf „Alle Effekte auf den Badges stoppen", Basisstation-Knopf „⏹ Alle stoppen", `POST /api/effect?m=12` oder MQTT-Payload `12`.
- **Nerves-Controller (Raspberry Pi):** Optionale Elixir/Nerves-App (`herz_schwarm_nerves/`) steuert den Schwarm über einen USB-ESP32-Bridge (ESP-NOW). LiveView Web-UI für Effekt-Steuerung, Beat-Tap-Tempo, Ambient-Farbwahl. Koexistiert mit der Basisstation auf Kanal 13. **Dev-Start auf Mac** (ohne Nerves-Build): siehe `herz_schwarm_nerves/MAC_SETUP.md`. Ab App 0.2.0 / Bridge 0.3.0 steuert die Seite **`/bridge-update`** die Bridge-Firmware per **UART-OTA** über das bestehende USB-Kabel (kein WLAN, kein `esptool`) — die Bridge braucht dafür einmalig einen USB-Flash mit dem neuen Partition-Schema `min_spiffs`; Details in Punkt 12 der nummerierten Doku. Ab App 0.2.0 / Bridge 0.4.0 zusätzlich im Dashboard: **Tap-Counter-Karte** (Modus `11`) und Knopf „Alle Effekte auf den Badges stoppen" (Modus `12`); BPM-Slider und Farbwähler wurden in Formulare gesetzt (vorher kamen Tempo- und Farbänderungen nie an) und das Verschieben des Tempo-Sliders startet den Beat nicht mehr. Betrieb auch direkt auf **Raspberry Pi OS** (systemd-Dienst, ohne Nerves-Firmware) — siehe *Betrieb auf dem Raspberry Pi*.

### Spezifische Hardware-Hinweise (Waveshare ESP32-S3-Matrix)
- **Pinout:** Die interne Matrix ist fest an **GPIO 14** verdrahtet. Die BOOT-Taste liegt auf **GPIO 0**.
- **Farben:** Die Matrix der Waveshare-Boards ist **RGB** verdrahtet (am Gerät verifiziert — mit `BGR` waren Rot und Blau vertauscht). Die Firmware initialisiert entsprechend `FastLED.addLeds<WS2812B, LED_PIN, RGB>`.
- **Sicherheit:** Da die Rückseite des Boards offene Kontakte hat, wird dringend empfohlen, diese mit Klebeband (Kapton) zu isolieren oder ein Gehäuse zu verwenden.
- **Eigene Hardware:** `herz_badge/` enthält das KiCad-Projekt für ein akkubetriebenes Badge (Waveshare-Schaltplan nachgezeichnet, Akku-Version platziert, noch nicht geroutet). Siehe `herz_badge/README.md`.

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
- **The Wave (base station):** A wave ripples outward from the base station: nearby badges light up first, distant ones later. One pass takes ~4 s; from badge FW 1.4.1 the wave **repeats endlessly** (4000 ms cycle) and only ends on a **manual stop** (mode `10`, or `12` to stop all effects): toggle in the web-UI, MQTT payload `10`, or Nerves dashboard — badges relay the stop with limited rebroadcasts, so it also reaches devices outside the base's range. Older badges don't understand the stop and finish after ~4 s as before. From badge FW 1.4.0, badges that hear the base fire by its signal strength (−45 dBm → immediately, −95 dBm → 2 s); others fire after the badge they got the wave from, plus 150–750 ms by signal to it. Every badge aligns to the shared wave start and keeps the shortest known path, so the wave also reaches badges out of the base's range.
- **Remote trigger (base station):** Compatible `SyncPacket` with `mode` **1** (virus), **2** (rainbow / singularity look), **3** (prime-party look), **4** (wave / RSSI ripple, 4 s cycle), **5** (beat pulse ~150 ms), **6** (RSSI zone colors), **7** (ambient color), **8** (strobe), **10** (stop the wave — ends the running wave, badge FW 1.4.1+), **11** (tap report — `virusID` = tap counter), **12** (stop all — global, `virusID = 0`). From badge FW **1.5.0** all visual effects run **endlessly** until stopped or until a newly started visual effect replaces them ("last effect wins" — beat and identify are kept). The previous fixed windows (virus 3 s, rainbow 15 s, prime 12 s, zones 5 s, ambient 30 s, strobe 2 s) are now only **nominal cycle lengths** after which the effect repeats. Exceptions: **beat** remains a 150 ms pulse per packet, **identify** (mode 9) stays at 10 s. A fresh `virusID` per effect avoids re-triggering; while active, badges forward the same `mode` for swarm propagation.
- **Tap counter (BOOT button, badge FW 1.5.0+):** Short BOOT presses (**≤ 250 ms** — the same events that count as a dot in morse input; morse itself is unchanged) are counted and reported as mode `11` (`virusID` = counter, monotonic; sent 3× at 60 ms spacing plus a re-send after 1.2 s, and once at boot). Other badges relay foreign tap packets with limited rebroadcast (**23 bytes** with the origin MAC appended) and keep the highest value per MAC (dedup). The counter is persisted to NVS with throttling (namespace `hstap`, max. 1 write/30 s). In the Nerves app the chain ends on a **Tap-Counter card** (total and per badge, reset with confirmation — reset only zeroes the display, badge counters keep running).
- **Stop all (mode `12`, badge FW 1.5.0+):** Global stop (`virusID = 0`): badges deactivate all effect slots except identify and relay the stop with limited rebroadcast (max. 3 sends, ~60 ms apart, then a 1000 ms lock — same pattern as the wave stop). Reachable via the dashboard button "Alle Effekte auf den Badges stoppen", the base station button "⏹ Alle stoppen", `POST /api/effect?m=12`, or MQTT payload `12`.
- **Nerves Controller (Raspberry Pi):** Optional Elixir/Nerves app (`herz_schwarm_nerves/`) controls the swarm via a USB ESP32 bridge (ESP-NOW). LiveView web-UI for effect control, beat tap-tempo, ambient color picker. Coexists with the base station on channel 13. From app 0.2.0 / bridge 0.3.0 the **`/bridge-update`** page pushes new bridge firmware via **UART-OTA** over the existing USB cable (no Wi-Fi, no `esptool`) — existing bridge devices first need one USB flash with the new `min_spiffs` partition scheme. **Security note:** the `/bridge-update` page has **no login** — anyone who can reach the app on the network can upload and flash bridge firmware. Run the app only in a trusted network or restrict access at the network level (firewall/VPN/LAN segment); there is deliberately no login yet, unlike the base station's OTA, which uses HTTP Basic Auth. From app 0.2.0 / bridge 0.4.0 the dashboard also shows a **Tap-Counter card** (mode `11`) and an "Alle Effekte auf den Badges stoppen" button (mode `12`); the BPM slider and color picker now sit inside forms (`phx-change` does not fire on standalone inputs outside a form, so tempo and color changes never arrived), and moving the tempo slider no longer starts the beat (start only via "Start"). The app currently runs on plain **Raspberry Pi OS (Debian 13, aarch64)** as systemd service `herz-schwarm` on port 4000 — no Nerves firmware; see `herz_schwarm_nerves/MAC_SETUP.md`.

### Specific Hardware Notes (Waveshare ESP32-S3-Matrix)
- **Pinout:** Internal matrix is wired to **GPIO 14**. BOOT button is on **GPIO 0**.
- **Color Order:** The matrix is wired **RGB** (verified on device — with `BGR`, red and blue were swapped). The firmware initializes `FastLED.addLeds<WS2812B, LED_PIN, RGB>`.
- **Safety:** As the back of the board has exposed contacts, it is highly recommended to insulate it with tape (Kapton) or use a 3D-printed case.
- **Own hardware:** `herz_badge/` holds the KiCad project for a battery-powered badge (the Waveshare schematic redrawn, the battery version placed, not yet routed). See `herz_badge/README.md`.

### Build, flash & serial monitor (Arduino CLI)
- **FQBN:** `esp32:esp32:esp32s3` — sketch folder = repository root (`Herz_Schwarm_CCC_V.ino`). Port: `arduino-cli board list`.
- **Production build:** `compile` + `upload` without debug flags (smaller binary, no serial overhead in the loop).
- **Serial debug on USB (ESP32-S3):** enable **USB CDC On Boot** (`CDCOnBoot=cdc`) and `ENABLE_SERIAL_DEBUG=1`. Because `upload` has no `--build-property`, use `--build-path build_debug` on compile and `--input-dir build_debug` on upload — see the **Arduino CLI** subsection under *Setup & Configuration* for copy-paste commands.
- **Live log:** `arduino-cli monitor -p <port> -c baudrate=115200` in an **interactive** terminal; stop with `Ctrl+C` before flashing again.
- **Batch flash (several devices):** `scripts/batch_flash_herz_schwarm.sh` needs **esptool** on `PATH` in addition to arduino-cli. See *Batch-Update* under *Setup & Configuration* (German) for options and the log files `firmware_update_log.csv` / `firmware_update_log.md`.
- **Interactive TUI (v0.1.1+):** running the same script in a terminal with `pyserial` installed auto-launches an ANSI menu (`scripts/flash_gui.py`) for port scanning, build mode (release/debug), compile, flash + MAC-read (parsed from upload output, no separate `esptool read_mac`), and log view. TUI covers **flash operations only** — effect control (modes 1–8, plus wave stop `10` and stop-all `12`) stays on the base station via Web-UI (port 80) or MQTT. macOS + Linux supported; Windows in a later release.
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

### Betrieb auf dem Raspberry Pi
Die Phoenix-App läuft aktuell **ohne Nerves-Firmware** direkt auf **Raspberry Pi OS (Debian 13, aarch64)** als systemd-Dienst `herz-schwarm` auf Port **4000** — kein Nerves-Build, kein `mix release`. Setup-Details (Autostart, Log, Updates) stehen in `herz_schwarm_nerves/MAC_SETUP.md`; hier bewusst nur der Verweis, keine doppelte Anleitung.

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

### CLI Pseudo-GUI (interaktiv, ab v0.1.1)

`scripts/batch_flash_herz_schwarm.sh` startet **automatisch** eine interaktive TUI, wenn ein TTY erkannt wird und `pyserial` installiert ist. Die TUI (`scripts/flash_gui.py`) ist ein dünner Wrapper um die gleiche Logik — nutzt aber ANSI-Boxen für Menü, Live-Output und Multi-Select.

**Voraussetzung** (einmalig):
```bash
pip3 install --user pyserial
```

**Start:**
```bash
./scripts/batch_flash_herz_schwarm.sh       # TUI automatisch
./scripts/batch_flash_herz_schwarm.sh --no-gui   # Bash-Modus erzwingen
./scripts/batch_flash_herz_schwarm.sh --gui      # TUI erzwingen (Fehler wenn nicht möglich)
python3 scripts/flash_gui.py               # TUI direkt starten
```

**Hauptmenü (6 Punkte):**
| Taste | Funktion |
|-------|----------|
| `1` | ESP32-S3-Ports scannen + Multi-Select (`all` oder Komma-getrennte Nummern) |
| `2` | Build-Modus: Release ↔ Debug toggle |
| `3` | Firmware kompilieren (Live-Stream von arduino-cli) |
| `4` | Flashen + MAC-Read pro Port, mit Progress `[2/5] /dev/cu.usbmodem…` |
| `5` | Log anzeigen (letzte 20 Zeilen aus `firmware_update_log.md`) |
| `q` | Beenden |

**Geltungsbereich:** TUI ist **nur** für **Flash-Operationen** zuständig (Compile, Upload, MAC-Read, Log). Effekt-Steuerung (Modes 1–8 + Wellen-Stopp `10` + Alle stoppen `12`, Virus/Regenbogen/Beat/Ambient/…) läuft weiterhin über die **Basisstation**: per **Web-UI** (Port 80) oder per **MQTT** (Broker konfiguriert in NVS). Der TUI-Flasher hat keinen ESP-NOW-Adapter und ist deshalb kein Effekt-Tool.

**Plattformen:** macOS (primär, getestet), Linux (sekundär, gleicher Code). Windows: nicht in v0.1.1 (geplant v0.2.0).

**Logs:** werden in die **gleichen Dateien** angehängt wie der Bash-Modus (`firmware_update_log.csv` / `firmware_update_log.md`) — keine Duplikation, vollständige Audit-Trail über alle Läufe und Tools.

**Änderungen v0.1.0 → v0.1.1 (Punkt-Release):**
- **MAC aus Upload-Output geparst** statt separates `esptool read_mac` — kein Bootloader-Reset-Race mehr, ~3s pro Board gespart
- **arduino-cli Path-Fallback** — funktioniert auch wenn das Binary nicht im PATH ist (z. B. nur in `/Applications/Arduino IDE.app/...`)
- **argv-Bug behoben** — `arduino-cli` wurde doppelt als Binary + Sub-Command übergeben (`unknown command "arduino-cli"`)
- **Auto-Build vor Flash** — wenn `build_batch_gui/*.bin` fehlt, wird automatisch kompiliert
- **23/23 Unit-Tests** in `flashlib/` grün

**Verifiziert mit 3 ESP32-S3-Badges** (18:58 Uhr, Firmware 1.1.0):
| Port | MAC |
|------|-----|
| `/dev/cu.usbmodem101`  | `34:b7:da:53:6b:98` |
| `/dev/cu.usbmodem1101` | `3c:0f:02:e4:61:00` |
| `/dev/cu.usbmodem1101` | `a0:f2:62:ec:3c:c8` |

### Serial-Debug & Morse-Logging
- **Aktivierung:** Im Sketch `ENABLE_SERIAL_DEBUG` auf `1` setzen *oder* beim Kompilieren `-DENABLE_SERIAL_DEBUG=1` wie oben.
- **Aus:** Standard im Sketch ist `0` — dann gibt es **keinen** Serial-Code in der Hauptschleife (kein Einfluss auf die Animation).
- **Mit Debug an:** Es erscheinen u. a. alle 2 s eine **Status**-Zeile (Peers, RSSI, Helligkeit, Morse-Puffer) und **sofort** bei jedem erkannten Morse-Zeichen eine Zeile `[Morse]` mit Dauer in ms; nach 800 ms Pause wird das Wort ausgewertet (`VIRUS` bei exakt `-.-.`, sonst `ignoriert`).
- **Morse-Regel im Code:** Taste gedrückt halten **≤ 250 ms** → Punkt `.`, **> 250 ms** → Strich `-`. Nach **800 ms** ohne neues Zeichen wird der Puffer geleert und geprüft.

### Firmware-Version (Schema A.B.C.D)

Im Sketch `Herz_Schwarm_CCC_V.ino` oben bei den `FW_VERSION_*`-Defines. Versionsschema **A.B.C.D**:

| Komponente | Name | Bedeutung | Wann erhöhen? |
|------------|------|-----------|---------------|
| **A** = `FW_VERSION_MAJOR` | Major | Breaking Change, Architektur-Wechsel | Nur auf speziellen Wunsch (per Diskussion) |
| **B** = `FW_VERSION_MINOR` | Minor | Großes neues Feature (z. B. TUI, neue Effekte, neues Funk-Protokoll) | Nach Diskussion, vor Merge nach `main` |
| **C** = `FW_VERSION_PATCH` | Patch | Kleines Feature / Refactor / Bugfix | Nach Diskussion, max 99, danach B hoch |
| **D** | Build | **Git-Commit-Zähler seit letztem A.B.C-Wechsel** | **Nur in Git-Tags**, nicht im Code (würde sonst Neukompilation bei jedem Commit erfordern). Tag-Format: `v1.2.0.5` = 5 Commits seit `v1.2.0` |

**Anzeige im Badge / Basisstation** (ohne D, da SyncPacket nur 17 Byte hat):

| Build | Anzeige (Beispiel) | Bedeutung |
|--------|-------------------|-----------|
| **Release** (`ENABLE_SERIAL_DEBUG=0`) | `1.2.0` | `FW_VERSION_MAJOR.MINOR.PATCH` |
| **Debug** (`ENABLE_SERIAL_DEBUG=1`) | `1.2.01+debug` | `FW_VERSION_MAJOR.MINOR` + **`FW_DEBUG_BUILD`** zweistellig (`01`…`99`) + Kennzeichnung `+debug` |

**Versions-Helper** (`scripts/version.sh`):
```bash
scripts/version.sh current        # aktuelle A.B.C aus .ino
scripts/version.sh next-tag       # naechster vA.B.C.D-Tag (D = Commits seit vA.B.C.0)
scripts/version.sh since v1.2.0.0 # Anzahl Commits seit Tag
scripts/version.sh tag            # annotierten Tag setzen
```

**Beispiel:** Code-Stand ist `1.2.0`, seit `v1.2.0.0` gab es 5 Commits → Tag `v1.2.0.5`. Nach Merge in `main` und Diskussion über ein neues Feature wird C auf `1` gesetzt → `1.2.1` → nächster Tag wird `v1.2.1.0`. Bump auf `1.3.0` (großes Feature) → C wieder auf `0` → `v1.3.0.0`. Bump auf `2.0.0` (Breaking Change) → kompletter Reset.

**Aktueller Stand:** `1.5.0` (neu: alle visuellen Effekte laufen endlos bis Stopp bzw. bis ein neuer Effekt sie ersetzt; Tap-Meldung via BOOT-Taste (Modus `11`) und globaler Stopp (Modus `12`)) — letzter Tag `v1.3.0.0`. Versionen aller Module: siehe *Versionen aller Module*.

**Änderungen v1.1.0 (Performance-Optimierung):**
- `String` → `char[12]` für Morse-Puffer (kein Heap-Overhead)
- Peer-Tracking: Hash-Index statt O(n²)-Scan
- `isPrime()` → Lookup-Tabelle (O(1))
- Herz-Maske: 64-bit Bitmaske statt 2D-Array
- Wave-Rebroadcast: nicht-blockierend statt `delay()`
- Frame-Limit: dynamisch statt festes `delay(20)`
- Effekt-State: Array-basiert statt 24 Einzelvariablen
- `smoothRSSI` als `volatile` für ISR-Sicherheit

**Pflege:**
- **`FW_VERSION_PATCH`** (und bei Bedarf MINOR/MAJOR) bei **Releases / Merge nach `main`** anheben (SemVer-üblich).
- **`FW_DEBUG_BUILD`** nur auf dem **Debug-Zweig** bei jedem **sichtbaren neuen Debug-Stand** um 1 erhöhen, **höchstens 99**. Bei Überlauf: MINOR anheben und Debug-Zähler wieder bei `01` starten (oder neue Basis-Version festlegen — im Team einheitlich halten).
- Nach größeren Änderungen: Kurzkommentar im Sketch neben den `FW_*`-Zeilen aktualisieren.

### Versionen aller Module

Das A.B.C.D-Schema oben beschreibt **nur die Badge-Firmware** (`Herz_Schwarm_CCC_V.ino`) — sie treibt auch den repo-weiten `vA.B.C.D`-Git-Tag. Die anderen vier Artefakte im Monorepo versionieren sich **unabhängig**, mit je eigenem `MAJOR.MINOR.PATCH`:

| Modul | Datei | Define/Feld | Aktuell |
|-------|-------|-------------|---------|
| Badge (Schwarm) | `Herz_Schwarm_CCC_V.ino` | `FW_VERSION_MAJOR/MINOR/PATCH` | 1.5.0 |
| Basisstation | `Herz_Schwarm_BaseStation/Herz_Schwarm_BaseStation.ino` | `BASESTATION_FW_MAJOR/MINOR/PATCH` | 0.4.0 |
| Bridge (Nerves-Adapter) | `herz_schwarm_nerves/firmware/esp32_bridge/esp32_bridge.ino` | `BRIDGE_FW_MAJOR/MINOR/PATCH` | 0.4.0 |
| Nerves/Phoenix-App | `herz_schwarm_nerves/mix.exs` | `@version` | 0.2.0 |
| Flash-Tooling (Python) | `scripts/flashlib/__init__.py` | `__version__` | 0.1.0 |

Jedes Modul wird unabhängig gebaut, geflasht bzw. deployed — eine einzige globale Versionsnummer für alles ist bewusst nicht das Ziel. `scripts/version.sh all` zeigt den aktuellen Stand aller fünf; `scripts/version.sh tag` schreibt sie als Snapshot in die Tag-Message des `vA.B.C.D`-Releases (D bleibt reiner Git-Commit-Zähler seit dem letzten `vA.B.C`-Tag, repo-weit — nicht auf Badge-Änderungen beschränkt).

### ESP-NOW Paket (Sync)
Kompaktes `SyncPacket` (packed): `magic_id`, `beatCounter`, `virusID`, `mode` wie bisher, plus **vier Byte** `ver_major`, `ver_minor`, `ver_rel`, `ver_dbg` (gesamt **17 Byte**). **Ältere Firmware** sendet nur **13 Byte** — wird weiter erkannt; die Version des Peers bleibt dann unbekannt (`?` im Debug-Log), bis ein Paket mit voller Länge ankommt. Zusätzliche Kosten: etwas größeres Payload pro Sendezyklus, wenig RAM pro Peer für die gespeicherte Version.

**`beatCounter` = Schwarm-Takt (ab Badge-FW 1.2.2):** gemeinsamer Phasen-Zähler, ein Puls = 65536 Einheiten; die Helligkeit wird ausschließlich daraus berechnet. Empfängt ein Badge einen Wert, der vor seinem eigenen liegt, holt er weich auf (Max-Regel, ab 4 Pulsen Abstand direkter Sprung) — der Schwarm folgt so dem schnellsten Badge und pulsiert synchron. Ausnahme Modus `7`: dort ist `beatCounter` die Farbe. Pakete von Stationen (Basisstation/Bridge, `ver_major == 0`) zählen ab 1.3.0 nicht für den Takt — sie senden ihr `millis()` und ließen den Schwarm sonst bei jedem Effekt in der Phase springen. Bis 1.2.1 lief der Puls über `beatsin8()` mit dem lokalen `millis()` und war deshalb nie wirklich synchron.

**Senderate:** Ab Badge-FW 1.2.1 broadcastet jedes Badge mit **20 Hz** (`SYNC_TX_INTERVAL_MS`, vorher 50 Hz = jeder Frame); bei einem Wechsel von `mode`/`virusID` wird sofort gesendet, damit sich Effekte ohne Verzögerung verbreiten. Das reduziert die Kanal-Last bei vielen Badges um 60 %.

**`mode`-Werte (Badge & Basisstation):** `0` normal; `1` Virus-Animation; `2` Fern-Regenbogen; `3` Fern-Primzahl-Party; `4` Welle (RSSI-/Hop-basierter Ripple, ~4 s pro Durchlauf, ab Badge-FW 1.4.1 **endlos** wiederholt bis Stopp via Modus `10` (oder `12` für alle Effekte); ab Badge-FW 1.4.0 hängen Badges 2× `uint16` an — Phase im laufenden Zyklus (`elapsed % 4000`, 0…3999; vorher „ms seit Wellenstart“, da `uint16` bei endloser Welle nach ~65 s überlaufen würde) und eigene Puls-Verzögerung, 21 Byte; Layout unverändert, abwärtskompatibel; Stationen senden weiter 17 Byte); `5` Beat-Puls (weiss, ~150 ms pro Paket — bleibt ein Einzel-Puls, kein Endlos-Effekt); `6` RSSI-Zonen-Farben (rot/gelb/blau, nominaler Zyklus ~5 s); `7` Ambient-Farbe (RGB aus `beatCounter`, nominaler Zyklus ~30 s); `8` Strobe (weisse Blitze, nominaler Zyklus ~2 s) — `1`–`4`, `6`–`8` laufen ab Badge-FW 1.5.0 **endlos**, bis Stopp (`10`/`12`) oder bis ein neuer visueller Effekt sie ersetzt, die Zeiten sind dann nur noch nominale Zykluslängen; `9` „Badge finden“ (ab Badge-FW 1.3.0: Paket = `SyncPacket` + **6 Byte Ziel-MAC**, 23 Byte; nur das Badge mit dieser STA-MAC blinkt 10 s grün mit voller Helligkeit, ältere Firmware ignoriert es); `10` Welle stoppen (ab Badge-FW 1.4.1 / Basisstation 0.3.1; das Stopp-Paket trägt die Ziel-Wellen-ID im `virusID`-Feld, `0` = Wildcard „stoppe die laufende Welle“; Badges beenden die Welle und leiten den Stopp begrenzt weiter — max. 3 Sendungen, ~60 ms Abstand, danach 1000 ms Sperre — damit er auch Badges außerhalb der Basis-Reichweite erreicht; dieselbe Welle (gleiche `virusID`) zündet danach nicht wieder, ein neuer Wellenstart (neue `virusID`) läuft normal an; ältere Badges ignorieren `10` und laufen wie bisher in ~4 s aus); `11` Tap-Meldung (ab Badge-FW 1.5.0: Badge zählt kurze Drücke auf die BOOT-Taste ≤ 250 ms — dieselben Ereignisse, die in der Morse-Eingabe ein Punkt sind, Morse unverändert — und sendet `mode = 11` mit dem **Zählerstand in `virusID`** (monoton): 3× im Abstand von 60 ms plus Nachsendung nach 1,2 s, beim Start einmal; fremde Tap-Pakete werden begrenzt weitergeleitet — **23 Byte** mit angehängter Ursprungs-MAC —, gemerkt wird je MAC nur der **höchste** Stand (Dedup); Zählerstand wird gedrosselt in NVS gespeichert (Namespace `hstap`, max. 1 Schreibvorgang/30 s)); `12` Alle stoppen (ab Badge-FW 1.5.0: **global** mit `virusID = 0`; Badges deaktivieren alle Effekt-Slots außer Identify und leiten den Stopp begrenzt weiter — max. 3 Sendungen, ~60 ms Abstand, danach 1000 ms Sperre, gleiches Muster wie der Wellen-Stopp). (`1`–`9` lösen Effekte aus — mit `11` seit 1.5.0 die Tap-*Meldung*, kein Effekt; `10` beendet die Welle, `12` stoppt alle Effekt-Slots außer Identify; `0` ist Standard nach Stopp bzw. bei reiner Nähe-Logik.)

---

## Projekt-Dokumentation (nummeriert)

1. **Badge-Sketch:** `Herz_Schwarm_CCC_V.ino` (Repo-Wurzel), Ziel-Hardware **Waveshare ESP32-S3-Matrix**, **FQBN** `esp32:esp32:esp32s3`, Kanal **13**, `MAGIC_ID` wie im Sketch.
2. **Basisstation-Sketch:** Ordner `Herz_Schwarm_BaseStation/`, Datei `Herz_Schwarm_BaseStation.ino`, **FQBN** `esp32:esp32:esp32s3`; Ethernet **W5500** (Referenz-Pins Spotpear: SCK 13, MISO 12, MOSI 11, CS 14, RST 9, INT 10).
3. **Firmware-Version Basisstation:** `BASESTATION_FW_MAJOR/MINOR/PATCH` im Basisstation-Sketch; in der Web-UI und in JSON (`/api/peers` → `station`) sichtbar (JSON-Key `station` ist ein fester String, unabhängig vom Define-Namen).
4. **Web-UI Basisstation:** **http://herz-base.local** (mDNS, ab 0.2.0) bzw. HTTP Port **80** auf der per DHCP vergebenen Ethernet-IP (Hostname `herz-base`, IP auch im Serial-Log `ETH IP: …`): Peers-Tabelle (Polling), alle Effekte **1–8** (Virus / Regenbogen / Primzahl-Party / Welle / Beat / Zonen / Ambient mit Farbwähler / Strobe), **MQTT-Konfiguration** (Formular). Ab 0.3.1: Der Welle-Button ist ein Toggle („🌊 Welle“ ↔ „⏹ Welle stoppen“, sendet Modus `10`); die Basisstation bleibt im Versand zustandslos und lernt den laufenden Wellenzustand aus den weitergeleiteten Badge-Paketen (Modus 4 → läuft, Modus 10 → gestoppt), angezeigt über das Peers-Polling (`wave`). Ab 0.4.0: Knopf **„⏹ Alle stoppen"** (Modus `12`); Tap-Zahlen (Modus `11`) werden in der Web-UI **nicht** angezeigt — sie stehen nur als `taps` je Peer in `GET /api/peers` und als Ereignis auf dem MQTT-Status-Topic.
5. **REST-API Basisstation:** `GET /api/peers` (JSON: Station-Version, `wave` (`true`/`false` — gelernt aus Badge-Paketen: Modus 4 → läuft, Modus 10 → gestoppt), Peer-Liste mit MAC, RSSI, Firmware-String, Alter und — ab 0.4.0 — `taps` (Tap-Zählerstand je Peer); `GET /api/peers` enthält außerdem `mqtt.enabled`/`mqtt.connected`; `POST /api/effect?m=1…8|10|12` (`m=10` stoppt die laufende Welle, ab 0.3.1; `m=12` stoppt alle Effekt-Slots außer Identify — global, ab 0.4.0; bei `m=7` optional `&c=RRGGBB` als Ambient-Farbe, Default Weiß; ungültiges `m` → HTTP 400); `POST /api/virus` (Alias für `m=1`); `POST /api/identify?mac=AA:BB:CC:DD:EE:FF` („Badge finden“, Modus 9, 3× gesendet); `POST /api/ota` (Firmware-Upload, multipart, HTTP Basic Auth `admin` / OTA-Passwort, danach Neustart); `GET /api/mqtt` (Konfiguration **ohne** Passwort, mit `has_password` und `connected`); `POST /api/mqtt` (Form-URL-encoded: `en`, `host`, `port`, `user`, optional `pass`, `ts`, `tc` — leeres Passwort = unverändert).
6. **MQTT:** **Klartext-TCP** (typisch Port **1883**), **kein TLS**. Einstellungen in **NVS** (`Preferences`, Namespace `hs_mqtt`); Broker per **Hostname oder IP** (`Network.hostByName`). Topics konfigurierbar: Status (Publish, JSON wie Peers-Kurzform), Befehl (Subscribe). Befehls-Payload: leer → Virus (`m=1`, wie bisher); `N` → Effekt `N` (1–8); `10` → laufende Welle stoppen (ab Basisstation 0.3.1; das Stopp-Paket trägt die zuletzt gelernte Ziel-Wellen-ID im `virusID`-Feld, `0` = Wildcard); `12` → alle Effekte stoppen (ab 0.4.0, globales Stopp-Paket mit `virusID = 0`); `7:RRGGBB` → Ambient-Farbe. Ab 0.4.0 publiziert die Basisstation bei einem **neuen Tap-Höchststand** zusätzlich `{"evt":"tap","mac":"…","count":N}` auf dem Status-Topic.
7. **Kompilieren Basisstation:** `arduino-cli compile Herz_Schwarm_BaseStation` — **ohne `--fqbn`**, Board-Optionen kommen aus `Herz_Schwarm_BaseStation/sketch.yaml` (`PartitionScheme=no_fs`: 2× 2 MB App statt 1,25 MB, Flash-Auslastung ~52 % statt 78 %; `CDCOnBoot=cdc`: Serial-Log über USB). Ein explizites `--fqbn` überschreibt die Datei. In der Arduino IDE: *Partition Scheme* „No FS 4MB (2MB APP x2)“ und *USB CDC On Boot* „Enabled“ wählen. NVS-Offset ist identisch zu „Default“ → MQTT-Konfiguration bleibt beim Umstellen erhalten.
8. **Flashen Badge:** `arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32s3 .` im Repo-Wurzelverzeichnis; Port mit `arduino-cli board list`.
9. **Flashen Basisstation:** `arduino-cli upload -p <PORT> Herz_Schwarm_BaseStation` (ebenfalls ohne `--fqbn`, damit die neue Partitionstabelle mitgeflasht wird). **Ab 0.3.0 auch per OTA** über die Web-UI (Karte *Firmware-Update*): `arduino-cli compile --export-binaries Herz_Schwarm_BaseStation` und `Herz_Schwarm_BaseStation/build/esp32.esp32.esp32s3/Herz_Schwarm_BaseStation.ino.bin` hochladen — das **App-Binary** (auf dem Gerät liegt es nach dem Update z. B. als `Herz_Schwarm_BaseStation_0.4.0.bin`); **nicht** `.merged.bin`, weder Bootloader noch Partitionstabellen. Das **OTA-Passwort** ist einkompiliert: im öffentlichen Repo steht nur ein Platzhalter, das echte Passwort gehört in `Herz_Schwarm_BaseStation/ota_secret.h` (gitignored, Vorlage `ota_secret.h.example`). Ohne diese Datei warnt die Web-UI. Die erste Version mit OTA muss einmal per USB drauf. (**Nicht verwechseln:** Das Update der *Basisstation* ist dieser HTTP-Upload; die ESP32-**Bridge** der Nerves-App hat kein Netzwerk und wird per UART-OTA aus dem Dashboard aktualisiert — Punkt 12a.)
9a. **Batch-Update Badges:** `scripts/batch_flash_herz_schwarm.sh` (siehe Abschnitt *Batch-Update*), Log: `firmware_update_log.csv` / `firmware_update_log.md`, Build-Cache `build_batch/`.
10. **Build-Artefakte:** Ordner `build_debug/`, `build_batch/` und `build_basestation/` sind in `.gitignore` und gehören nicht ins Repository.
11. **Abwärtskompatibilität:** Badges mit alter Firmware reagieren nur auf **`mode == 1`** (Virus); `2`–`8` werden ignoriert. Basisstation und Nerves-Controller können trotzdem alle Modi senden. Modus `10` (Welle stoppen) versteht nur Badge-FW ab **1.4.1** — ältere Badges ignorieren ihn und laufen wie bisher in ~4 s aus (nicht endlos); gesendet wird er ab Basisstation **0.3.1**. Modi `11` (Tap-Meldung) und `12` (Alle stoppen) versteht nur Badge-FW ab **1.5.0** — ältere Badges ignorieren beide; `12` senden Basisstation ab **0.4.0** und das Nerves-Dashboard ab App 0.2.0 / Bridge 0.4.0. Tap-Weiterleitung (23 Byte) und Tap-Anzeige in der App setzen Bridge **0.4.0** voraus.
12. **Nerves-Controller:** Ordner `herz_schwarm_nerves/`, Elixir/Nerves-App für **Raspberry Pi 4**. Steuert Badges über USB-ESP32-Bridge (ESP-NOW Kanal 13). Web-UI auf Port 4000 mit Badge-Liste und „🔎 Finden“ (Modus 9, ab Bridge 0.2.0 / App 0.1.2). Bridge-Firmware: `herz_schwarm_nerves/firmware/esp32_bridge/esp32_bridge.ino` (Arduino, benötigt ArduinoJson-Library). Effektmodi 1–8 plus Wellen-Stopp (Modus `10`, Welle-Button als Toggle, ab Bridge 0.2.1 / App 0.1.3), Beat-Tap-Tempo, Ambient-RGB-Steuerung. Koexistiert mit Basisstation (unterschiedliche `virusID`s). Ab App 0.2.0 / Bridge 0.4.0: Dashboard mit **Tap-Counter-Karte** (Modul `HerzSchwarm.TapCounter`: Merge über Maximum je Badge, Gesamtsumme inkl. verdrängter Badges über ein High-Water-Mark, max. 64 Badges; Anzeige der Einzelergebnisse mit Rückfrage-Reset — Reset setzt nur die *Anzeige* auf 0 via Offset je MAC, die Badge-Zähler laufen weiter. Persistenz: JSON-Datei, Pfad aus Config `:tap_store_path`, Default `~/.local/share/herz-schwarm/taps.json`, Schreiben gedrosselt auf max. alle 5 s, atomar). Neuer Knopf **„Alle Effekte auf den Badges stoppen"** (Modus `12`). **Bedienfehler behoben:** BPM-Slider und Farbwähler hingen nicht an einem `<form>` — `phx-change` feuert auf Einzel-Inputs nur innerhalb eines Formulars, deshalb kamen Tempo- und Farbänderungen nie an; jetzt in Formularen, und das Verschieben des Tempo-Sliders startet den Beat nicht mehr (Start nur über „Start"). Die App hat bewusst keinen Login — im Netz ist sie damit grundsätzlich ungeschützt.
12a. **Bridge-UART-Protokoll & UART-OTA (ab Bridge 0.3.0 / App 0.2.0):** Kommandos sind newline-JSON über Serial (115200 Baud, max. 256 Byte pro Zeile): neben `effect`/`status`/`peers`/`identify` neu `ota_begin` (`size`, optional informativ `ver`) → `Update.begin`, `ota_chunk` (`off`, `data` = Base64 über 96 Rohbytes) → `Update.write` mit je einem `ack`/`err` pro Chunk (strikt sequenziell, Wiederholung des letzten Chunks ist idempotent), `ota_end` → `Update.end(true)` + Neustart der Bridge, `ota_abort` → verwirft das Update. `pong` meldet zusätzlich `fw` (Bridge-Version) und `ota` (`idle`/`writing`/`error`); Firmware < 0.3.0 sendet beide Felder nicht. Ab Bridge 0.4.0 kommen über UART zusätzlich Tap-Meldungen an: `{"evt":"tap","mac":"AA:BB:CC:DD:EE:FF","count":N}` — nur bei neuem Höchststand einer MAC (Dedup in der Bridge). Während eines Updates antwortet `effect` mit `err` `busy: ota` (`status`/`peers` laufen weiter); ein verwaistes Update wirft die Bridge nach 30 s ohne Verkehr automatisch zurück (dann `ota:"error"` im pong, Effekte wieder möglich). **Voraussetzung Partitionierung:** `firmware/esp32_bridge/sketch.yaml` setzt `PartitionScheme=min_spiffs` (zwei App-Slots à ~1,9 MB); laut Build belegt die Firmware 46 % des Slots (S3) bzw. ~50 % (C3), mit dem `default`-Schema wären es 69 % von nur 1 310 720 B. Ein **bereits geflashtes Gerät muss einmalig per USB** mit dem neuen Schema geflasht werden (die Partitionstabelle wird mitgeschrieben) — erst danach funktioniert OTA; ohne OTA-Slot schlägt `Update.begin` fehl und die Update-Seite zeigt die Fehlermeldung. Bekannte Grenzen: keine eigene Prüfsumme pro Chunk (Integrität prüft `Update.end` über die Image-Prüfsumme), die App akzeptiert als Datei nur `.bin` mit ESP-Magic-Byte `0xE9`, der reale OTA-Ablauf auf Hardware ist noch nicht getestet. **Abgrenzung zur Basisstation (Punkt 9):** deren Update läuft als HTTP-Upload in der eigenen Web-UI — die Bridge hat kein Netzwerk, ihr Update kommt per UART aus dem Nerves-Dashboard. Neue Seite **`/bridge-update`**: zeigt Bridge-Firmware-Version und OTA-Zustand, Upload der Sketch-`.bin` (≈ 900 kB, z. B. `esp32_bridge.ino.bin`, max. 2 MB — **nicht** `.merged.bin`, nicht den Bootloader), Start/Abbruch, Fortschrittsbalken (Prozent + Bytes); der Dashboard-Header zeigt die Bridge-Version und verlinkt die Seite. Ablauf in der App: sequenziell in 96-Byte-Chunks, 1000 ms Timeout pro Chunk, max. 3 Wiederholungen, danach automatischer Abbruch; `ota_begin`/`ota_end` mit 20 s Timeout ohne Wiederholung; Gesamt-Timeout 10 min. Grobe Faustregel laut Implementierer: ~5–7 kB/s → ~2,5–4 min für ein ~900 kB-Image. Details: `herz_schwarm_nerves/MAC_SETUP.md`.
**Sicherheitshinweis (`/bridge-update`):** Die Update-Seite hat **keinen Login** — jeder, der die App im Netz erreicht, kann eine Bridge-Firmware hochladen und flashen. Die App nur in einem vertrauenswürdigen Netz betreiben oder den Zugriff auf Netzwerkebene beschränken (Firewall/VPN/LAN-Segment); ein Login gibt es bewusst noch nicht — im Gegensatz zur OTA der Basisstation (Punkt 9), die HTTP Basic Auth nutzt.
13. **Cursor / Arduino CLI:** Zusätzliche Befehle in `.cursor/rules/arduino-cli.mdc`.

### Code Adjustments
Ensure the FastLED initialization matches the Waveshare hardware (im Sketch ist die Farbreihenfolge wie dort verdrahtet gesetzt, siehe `Herz_Schwarm_CCC_V.ino`):
`FastLED.addLeds<WS2812B, 14, RGB>(leds, 64);` — die Matrix ist **RGB** verdrahtet (am Gerät verifiziert; mit `BGR` waren Rot und Blau vertauscht).

---
**Happy Hacking!** 🚀✨
