# Nerves-Controller: Entwicklung auf macOS und Betrieb auf dem Raspberry Pi

Stand: App 0.3.0, Bridge 0.5.0.

Der Nerves-Controller ist als Nerves-Firmware-Image für **Raspberry Pi 4** angelegt. Dieselbe Code-Basis läuft aber als **normale Elixir/Phoenix-App** — auf dem Mac zum Entwickeln und Testen der Web-UI, auf dem Pi im Betrieb (systemd-Dienst, ohne Nerves-Build, ohne SD-Karten-Image).

Inhalt: Einrichtung auf dem Mac · Bridge flashen · Port-Auswahl und Web-UI · Bridge-Protokoll (Ack, Peers, Taps) · Bridge-Update (`/bridge-update`) · Badge-Update per Funk (`/badge-update`) · Betrieb auf dem Raspberry Pi · Tests · Troubleshooting · Bekannte Bugs.

## Voraussetzungen (einmalig)

```bash
# Elixir + Erlang (via Homebrew, deklarativ ueber nix-homebrew)
brew install elixir

# Asdf-Alternative (Version Manager, empfohlen)
brew install asdf
asdf plugin add erlang
asdf plugin add elixir
cd herz_schwarm_nerves
asdf install          # nimmt die Versionen aus .tool-versions (Elixir 1.15.4 / OTP 26.2)
```

Das Projekt verlangt Elixir `~> 1.15`; neuere Versionen gehen ebenfalls (auf dem Pi laufen Elixir 1.18 / OTP 27). Die CI testet mit den Versionen aus `.tool-versions`.

Prüfen:
```bash
elixir --version
# Elixir 1.15.4 (compiled with Erlang/OTP 26)

# Einmalig: ohne dieses Archiv schlägt jedes mix-Kommando fehl (mix.exs deklariert es)
mix archive.install hex nerves_bootstrap "~> 1.13" --force
```

## Setup (einmalig pro Repo)

```bash
cd <Repo>/herz_schwarm_nerves

# Dependencies laden (Phoenix, LiveView, circuits_uart, ...)
mix deps.get

# Assets (Tailwind CSS + esbuild JS) bauen
mix assets.setup
mix assets.build
```

`mix.exs` hat Nerves als **target-only dependency** — auf `MIX_TARGET=host` (Default auf Mac) wird Nerves übersprungen. Kein Cross-Compile nötig.

## Bridge flashen (einmalig)

Du brauchst einen simplen ESP32 (oder ESP32-S3) als USB-Bridge zwischen Mac und den Badges:

```bash
# Aus dem Repo-Wurzel
# ESP32-S3: FQBN inkl. CDCOnBoot=cdc kommt aus firmware/esp32_bridge/sketch.yaml
arduino-cli compile herz_schwarm_nerves/firmware/esp32_bridge/
arduino-cli upload -p /dev/cu.usbmodem14101 herz_schwarm_nerves/firmware/esp32_bridge/
```

**Wichtig bei ESP32-S3 mit nativem USB:** `CDCOnBoot=cdc` ist Pflicht — ohne geht `Serial` auf UART0 statt auf das USB-Kabel, und die Bridge antwortet am Mac/Pi nicht. `sketch.yaml` setzt das automatisch, solange kein eigenes `--fqbn` übergeben wird (für den C6 unten wird `--fqbn` explizit gesetzt und überschreibt die Datei).

**Neu ab Bridge 0.3.0 — Partition-Schema:** `sketch.yaml` setzt zusätzlich `PartitionScheme=min_spiffs` (zwei App-Slots à ~1,9 MB, `ota_0`/`ota_1`) — Voraussetzung für das UART-OTA aus dem Dashboard (Abschnitt „Bridge-Update über das Dashboard"). **Ein bereits geflashtes Gerät muss einmalig per USB mit diesem Sketch nachgezogen werden**, dabei wird die Partitionstabelle mitgeschrieben; erst danach funktioniert OTA. Ohne OTA-Slot schlägt `Update.begin` fehl und die Update-Seite zeigt die Fehlermeldung. Beim C6/C3-Flash unten (explizites `--fqbn`) gehört `PartitionScheme=min_spiffs` in den FQBN, sonst greift `sketch.yaml` nicht und OTA ist nicht möglich.

Der Port `/dev/cu.usbmodem14101` ist exemplarisch — `arduino-cli board list` zeigt deinen echten. **Sicherstellen, dass der ESP32 kein Badge-Sketch drauf hat**, sondern die `esp32_bridge.ino`.

## App starten

```bash
cd herz_schwarm_nerves

# Auto-Detect: fragt alle ESP32-/USB-Seriell-Ports mit "status" an, nimmt den mit "pong"
mix phx.server

# Oder mit explizitem Port:
UART_DEVICE=/dev/cu.usbmodem14101 mix phx.server
```

Browser: `http://localhost:4000`

## Was die App auf dem Mac macht

| Komponente | Verhalten auf Mac |
|------------|-------------------|
| Phoenix.PubSub | läuft lokal |
| `HerzSchwarm.Bridge` | öffnet den erkannten Bridge-Port (115200 Baud) |
| `HerzSchwarm.EffectEngine` | läuft im Speicher |
| `HerzSchwarm.PeerTracker` | hört auf Bridge-Events |
| LiveView Web-UI | `http://localhost:4000` |

**Effekte gehen über die USB-Bridge per JSON raus** → Bridge sendet ESP-NOW-Broadcast auf Kanal 13 → alle Badges empfangen das. **Gleicher Kanal wie die ESP32-S3-Basisstation** — sie koexistieren (beide senden `magic_id = 0x421337CC`).

## Architecture-Diagram

```
┌─────────────────────────────────────────────────────┐
│ Mac (GallifreyM1)                                   │
│                                                     │
│  ┌──────────────┐  Phoenix.LiveView  ┌──────────┐  │
│  │ EffectEngine │ ◄──── PubSub ────► │ Dashboard│  │
│  └──────┬───────┘                     │ Web-UI   │  │
│         │ JSON                        │ :4000    │  │
│  ┌──────▼───────┐  UART/Serial       └──────────┘  │
│  │   Bridge     │ ◄───────► /dev/cu.usbmodem101     │
│  └──────┬───────┘  115200 Baud                      │
│         │                                            │
└─────────┼────────────────────────────────────────────┘
          │ USB-Kabel
┌─────────▼─────────┐
│  ESP32-Bridge     │  esp32_bridge.ino
│  (XIAO ESP32-C6)  │  → empfängt JSON via UART
└─────────┬─────────┘  → sendet ESP-NOW Broadcast
          │            (Kanal 13, MAGIC_ID 0x421337CC)
          │ 2.4 GHz ESP-NOW
          ▼
   ┌──────┴──────┐
   │ 8x8 Badges  │  Herz_Schwarm_CCC_V.ino
   │ ESP32-S3    │  → empfängt SyncPacket
   └─────────────┘  → führt Effekt aus
```

## Quick-Start (TL;DR)

```bash
# 1. Einmalig
nix profile add nixpkgs#elixir nixpkgs#erlang
pip3 install --user pyserial

# 2. C6 flashen (einmalig, dann läuft die Bridge)
arduino-cli compile --fqbn esp32:esp32:esp32c6 --build-path /tmp/c6_build herz_schwarm_nerves/firmware/esp32_bridge/
arduino-cli upload -p /dev/cu.usbmodem101 --fqbn esp32:esp32:esp32c6 --input-dir /tmp/c6_build herz_schwarm_nerves/firmware/esp32_bridge/

# 3. Nerves starten
cd herz_schwarm_nerves
mix deps.get
mix compile
UART_DEVICE=/dev/cu.usbmodem101 mix phx.server

# 4. Browser: http://localhost:4000
```

## Bridge-Firmware flashen (C3 / C6 / ESP32 / ESP32-S3)

### Voraussetzungen prüfen

```bash
# arduino-cli (sollte im PATH sein oder im Arduino-Bundle liegen)
ls /Applications/Arduino\ IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli

# pyserial
pip3 install --user pyserial
```

### Flash-Schritte

1. **C6 per USB-C anschließen**
2. **Port ermitteln** (ändert sich nach jedem USB-Reset):

   ```bash
   ls /dev/cu.usb*
   # → /dev/cu.usbmodem101  (XIAO C6)
   # → /dev/cu.usbmodem14101 (S3 Badge)
   # → /dev/cu.usbserial-1410 (ESP32-S3 native USB)
   # → /dev/cu.SLAB_USBtoUART (CP2102)
   ```

3. **Compile + Upload**:

   ```bash
   arduino-cli compile --fqbn esp32:esp32:esp32c6 --build-path /tmp/c6_build herz_schwarm_nerves/firmware/esp32_bridge/

   arduino-cli upload -p /dev/cu.usbmodem101 \
     --fqbn esp32:esp32:esp32c6 \
     --input-dir /tmp/c6_build \
     herz_schwarm_nerves/firmware/esp32_bridge/
   ```

   Achtung: das explizite `--fqbn` überschreibt `sketch.yaml` — ohne `PartitionScheme=min_spiffs` im FQBN gibt es keine OTA-Slots und UART-OTA ist unmöglich (für OTA `esp32:esp32:esp32c6:PartitionScheme=min_spiffs` setzen; bereits geflashte Geräte brauchen den ersten Flash mit dem neuen Schema einmal per USB, siehe „Bridge flashen (einmalig)“).

4. **Verifizieren** (Serial-Log "bridge ready" sollte erscheinen):

   ```bash
   cat /dev/cu.usbmodem101 | head -5
   # → {"evt":"log","msg":"bridge ready"}
   ```

### C6-Spezifische Hinweise

- **ROM-Bootloader (PID 0x1001)**: Wenn das C6 im Download-Mode hängt, USB-Cabel kurz ziehen + Reset-Taste drücken
- **USB-CDC-Reset beim Serial-Open**: XIAO C6 hat das **nicht** (im Gegensatz zu ESP32-C3)
- **Channel 13** für ESP-NOW: Kanal ist in `esp32_bridge.ino` fest verdrahtet, Magic-ID `0x421337CC`

### ESP32-C3 flashen (die Bridge am Raspberry Pi)

Die am Pi hängende Bridge ist ein **ESP32-C3** mit nativem USB-CDC. FQBN (der Mac-Weg):

```bash
# min_spiffs = zwei App-Slots, nötig für OTA
arduino-cli compile --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc,PartitionScheme=min_spiffs \
  --export-binaries herz_schwarm_nerves/firmware/esp32_bridge/
```

**Vom Pi aus flashen (über USB-CDC, ohne Mac):**

```bash
# 1. esptool installieren
sudo apt-get install -y python3-pip
sudo pip3 install --break-system-packages esptool

# 2. App stoppen — sonst hält sie den Port
sudo systemctl stop herz-schwarm

# 3. Backup des aktuellen Flashs (4 MB, dauert ~25 s)
esptool --chip esp32c3 --port /dev/ttyACM0 read-flash 0x0 0x400000 ~/bridge_backup_<version>_4MB.bin

# 4. Neue Firmware schreiben (Dateien aus dem Build-Verzeichnis)
esptool --chip esp32c3 --port /dev/ttyACM0 write-flash \
  --flash-mode dio --flash-freq 80m --flash-size 4MB \
  0x0     esp32_bridge.ino.bootloader.bin \
  0x8000  esp32_bridge.ino.partitions.bin \
  0xe000  boot_app0.bin \
  0x10000 esp32_bridge.ino.bin

# 5. App wieder starten
sudo systemctl start herz-schwarm
```

Die tatsächlichen Dateinamen im Build-Verzeichnis heißen `esp32_bridge.ino.bootloader.bin` und
`esp32_bridge.ino.partitions.bin` (nicht `bootloader.bin` / `partitions.bin`).

**Hinweis:** Wurde die bereits laufende Bridge mit einem Schema **ohne** zweiten App-Slot geflasht, schlägt
OTA fehl (`Update.begin`, siehe „Bridge-Update über das Dashboard") — für Updates bleibt dann nur USB.

## Port-Auswahl und Web-UI

### Port-Auswahl (ab App 0.1.2)

Die Bridge wird zur Laufzeit erkannt (`lib/herz_schwarm/bridge.ex`, bei jedem (Re-)Connect neu):
1. `UART_DEVICE` env-var (höchste Priorität)
2. `config :herz_schwarm, :uart_device` (standardmäßig nicht gesetzt)
3. Auto-Detect: alle USB-Seriell-Ports von Espressif / CP210x / CH340 / FTDI werden der Reihe nach
   mit `{"cmd":"status"}` angefragt; der erste, der mit `pong` antwortet, ist die Bridge.
   Badges/Basisstation am selben Rechner antworten nicht und werden übersprungen.
   Nichts gefunden → Warnung im Log, neuer Versuch mit Backoff (2 s … 30 s).

### Port wechseln ohne Code-Änderung

```bash
# Anderes C6 (anderer USB-Port)
UART_DEVICE=/dev/cu.usbmodem14101 mix phx.server

# Pi 4: Auto-Detect findet ttyUSB* (CH340/CP2102) und ttyACM* (natives USB, z. B. ESP32-C3)
```

### Phoenix-Web-UI

- URL: `http://localhost:4000`
- Hauptmenü: 8 Effekt-Buttons, BPM-Slider, Tap-Beat, Ambient-Color-Picker
- Live-Updates via PubSub (kein Polling, WebSocket)
- Bridge-Status + Peer-Count in Header
- Ab App 0.2.0: Header zeigt die Bridge-Firmware-Version (aus `pong`, bei Bridge < 0.3.0 `?`) und verlinkt die Seite **`/bridge-update`** (siehe „Bridge-Update über das Dashboard“)
- Ab App 0.2.0 / Bridge 0.4.0: Karte **Tap-Counter** — Gesamtsumme und Wert je Badge, mit Reset
- Knopf **„Alle Effekte auf den Badges stoppen“** (sendet Modus 12, ab App 0.2.2 / Bridge 0.4.2 mit eigener Kennung je Stopp)
- Ab App 0.3.0 / Bridge 0.5.0: Link zur Seite **`/badge-update`** (siehe „Badge-Update per Funk“)
- Seite **`/diagnose`**: Zähler, Bridge-Uptime/Heap, Log-Filter, RSSI-Verlauf der Badges
- Effekte laufen **endlos**, bis gestoppt wird. Beat ist ein 150-ms-Puls, „Badge finden“ (Identify) blinkt 10 s grün
- **Stolperstein:** BPM-Slider und Ambient-Farbwähler müssen **innerhalb** eines Formulars gebunden sein
  (`form`/`field` mit `phx-change`) — LiveView feuert `phx-change` auf Einzel-Inputs nicht, ohne Formular
  ändern die Regler nichts an den Effekten

## UART-Device auf Mac

ESP32-Bridge erscheint als USB-Serial-Gerät. Mögliche Pfade:

| Pfad | Board | Hinweis |
|------|-------|---------|
| `/dev/cu.usbmodem*` | natives USB (ESP32-S3, ESP32-C3, XIAO ESP32-C6) | Nummer ändert sich je USB-Buchse |
| `/dev/cu.usbserial-*` | ESP32 mit USB-Seriell-Wandler (CH340, CP210x, FTDI) | je nach Treiber |
| `/dev/cu.SLAB_USBtoUART` | ESP32 mit CP210x (Silicon-Labs-Treiber) | |
| `/dev/cu.wchusbserial*` | ESP32 mit CH340 (WCH-Treiber) | alternative Bezeichnung |

**Finden:**
```bash
ls -la /dev/cu.usb* /dev/cu.wch* /dev/cu.SLAB* 2>/dev/null
# oder
ioreg -p IOUSB -l | grep -i "usb serial\|usb-serial"
```

## Wichtige Constraints

- **macOS first** (GallifreyM1), Linux secondary (x86_64)
- **Windows**: TUI-Flasher ab flashlib v0.2.0 (`python scriptslash_gui.py`); das Bash-Skript bleibt macOS/Linux
- **Effekt-Steuerung läuft NUR über diese Web-UI** (oder Basisstation), nie im TUI-Flasher
- **Version**: `Herz_Schwarm_CCC_V.ino` Defines sind nur für die Badge-FW + den `vA.B.C.D`-Git-Tag maßgeblich. Basisstation/Bridge/Nerves-App/flashlib versionieren sich unabhängig — vollständige Tabelle in `../README.md` (Abschnitt "Versionen aller Module")
- **Logs append-only**: `firmware_update_log.csv`/`.md` werden nie überschrieben

## Coexistenz mit der ESP32-S3+W5500-Basisstation

| Komponente | Kanal | Wer? |
|------------|-------|------|
| Basisstation (ESP32-S3+W5500) | 13 | hört passiv, sendet bei Effekt-Trigger |
| Nerves-Bridge (ESP32-C6) | 13 | hört passiv, sendet bei Effekt-Trigger |
| Badges | 13 | hören passiv auf beide |

**Zusammenspiel:**
1. Beide Stationen vergeben zufällige `virusID`s oberhalb von 99999 (der Bereich 1…99999 gehört dem Morse-Virus der Badges, ab Basisstation/Bridge 0.4.2 und App 0.2.2). Eine Kollision ist damit unwahrscheinlich.
2. Starten beide gleichzeitig einen Effekt, gewinnt auf jedem Badge der zuletzt empfangene („letzter Effekt gewinnt").
3. Stationen senden mit Hauptversion 0. Badges zählen sie nicht als Peer und nicht für den Takt; Basisstation und Bridge führen sich gegenseitig nicht in der Badge-Liste (ab 0.4.1).
4. Das Funk-Update der Badges kann nur die App über die Bridge auslösen, nicht die Basisstation.

**Wenn Probleme:** Eine Station deaktivieren (z. B. Web-UI der ESP32-S3-Basisstation nicht benutzen, nur Nerves verwenden, oder umgekehrt).

## Ack/Retry-Mechanismus der Nerves-Bridge (ab Bridge-FW v0.1.2, implizites Ack ab v0.1.3)

Nur der Nerves-Pfad (Modus 3: Matrix + Basisstation + Nerves) hat zuverlässige Zustellung. Modus 2 (Basisstation allein) bleibt bewusst fire-and-forget — dort existiert kein Ack.

**Ablauf:**
1. Bridge broadcastet ein `SyncPacket` (wie bisher).
2. **Implizites Ack (ab v0.1.3):** Badges broadcasten laufend ihr `SyncPacket` (20 Hz) und übernehmen dabei die `virusID` des gerade laufenden Effekts. Empfängt die Bridge ein SyncPacket mit der `virusID` des ausstehenden Effekts, gilt das als Ack. Jedes empfangene SyncPacket markiert die Station außerdem als aktiv. Funktioniert mit jeder Badge-Firmware, kein Extra-Paket nötig.
3. **Explizites Ack (weiterhin unterstützt):** Eine Station kann alternativ ein `AckPacket` (magic_id + virusID, 8 Byte) per ESP-NOW-Unicast an die Absender-MAC senden.
4. Haben nicht alle zuletzt aktiven (< 5s) Stationen innerhalb von 150ms bestätigt, broadcastet die Bridge das gleiche Paket erneut — max. 2 Retries (3 Sends insgesamt).
5. Stationen ohne Lebenszeichen seit 5s gelten als offline und blockieren keine Retries mehr; ihr Slot wird für neue Stationen wiederverwendet.

**Bis v0.1.2** wartete die Bridge ausschließlich auf `AckPacket`s — die Badge-Firmware sendet aber keine, daher blieb `peers` immer `0` und Retries wurden nie ausgelöst.

**Peer-Liste & Badge finden (Bridge ≥ 0.2.0):** `{"cmd":"peers"}` → je aktiver Station eine Zeile
`{"evt":"peer","mac":"A0:F2:62:EC:3B:B4","rssi":-74,"fw":"1.3.0","age":40}`, danach `{"evt":"peers","n":N}`.
`{"cmd":"identify","mac":"A0:F2:62:EC:3B:B4"}` sendet Modus 9 (SyncPacket + 6 Byte Ziel-MAC, 3×) — nur dieses
Badge blinkt 10 s grün (Badge-FW ≥ 1.3.0), Antwort `ack`. Der Pi pollt `peers` zusammen mit `status`;
das Dashboard zeigt die Liste mit „🔎 Finden“-Button (`HerzSchwarm.PeerTracker.identify/1`).

**Peer-Count:** `{"evt":"pong","peers":N,...}` liefert jetzt die echte Anzahl zuletzt aktiver Stationen (vorher immer `0`, das Feld wurde nie gesetzt). Der Pi pollt `{"cmd":"status"}` alle 5s automatisch (`HerzSchwarm.Bridge`), das Dashboard zeigt den Wert live über `PeerTracker`.

**Tap-Events (ab Bridge 0.4.0):** Badges zählen Taps und melden ihren Zählerstand im SyncPacket. Die Bridge
sendet zusätzlich eine Zeile
`{"evt":"tap","mac":"AA:BB:CC:DD:EE:FF","count":N}` — **nur wenn der Zählerstand über dem zu dieser MAC
bekannten Maximum liegt** (Dedup: dasselbe SyncPacket, sowie jeder gleiche oder kleinere Wert, erzeugt kein
Event). Startet ein Badge neu, beginnt sein Zähler bei 0; Werte unter dem bisherigen Maximum ignoriert die App,
bis der Badge wieder darüber liegt. Das Dashboard summiert die Werte (Karte „Tap-Counter", siehe
*Phoenix-Web-UI*).

**Für Stations-Firmware ohne eigenen SyncPacket-Broadcast** (separates Repo, nicht hier): nach Empfang eines validen `SyncPacket` ein `AckPacket{magic_id: 0x421337CC, virusID: <empfangene virusID>}` per `esp_now_send()` unicast an die Absender-MAC zurücksenden. Die Bridge-MAC muss dafür einmalig als ESP-NOW-Peer registriert werden (unverschlüsselt, Kanal 13).

## UART-OTA-Kommandos der Bridge (ab Bridge 0.3.0 / App 0.2.0)

Alle Kommandos laufen über die bestehende Serial-Verbindung (115200 Baud, newline-JSON,
max. 256 Byte pro Zeile — deshalb sind Chunks auf 96 Rohbytes begrenzt):

| Kommando | Beispiel (Pi → Bridge) | Wirkung auf der Bridge |
|----------|------------------------|------------------------|
| `ota_begin` | `{"cmd":"ota_begin","seq":7,"size":904880}` | `Update.begin(size)` — löscht den Ziel-Slot (kann 1–3 s dauern), dann `ack`; optional-Feld `ver` nur informativ |
| `ota_chunk` | `{"cmd":"ota_chunk","seq":8,"off":0,"data":"<base64, 96 Rohbytes>"}` | `Update.write`; pro Chunk genau ein `ack`/`err`; `off` = bisher geschriebene Rohbytes, strikt sequenziell — die Wiederholung des letzten Chunks wird idempotent nur bestätigt |
| `ota_end` | `{"cmd":"ota_end","seq":9}` | `Update.end(true)` (prüft die Image-Prüfsumme), `ack`, dann Neustart der Bridge |
| `ota_abort` | `{"cmd":"ota_abort","seq":10}` | verwirft das Update (`Update.abort`), Zustand zurück `idle`, `ack` |

`pong` (Antwort auf `{"cmd":"status","seq":N}`) meldet ab 0.3.0 zwei zusätzliche Felder —
`{"evt":"pong","peers":5,"uptime":12345,"free_heap":200000,"fw":"0.3.0","ota":"idle"}`:
`fw` = Bridge-Firmware-Version, `ota` = `idle` | `writing` | `error`. Ältere Bridges senden beide Felder nicht.

**Während eines Updates:** `effect` antwortet mit `err` `busy: ota`; `status` und `peers` laufen weiter.
Bleiben Chunks/Kommandos aus, verwirft die Bridge ein verwaistes Update nach **30 s** automatisch
(`Update.abort`, Log `ota timeout, aborted`; `pong` zeigt danach `ota:"error"`, Effekte sind wieder möglich).

**Bekannte Grenzen:** keine eigene Prüfsumme pro Chunk — die Integrität prüft `Update.end` über die
Image-Prüfsumme; die Dateiprüfung der App akzeptiert nur `.bin` mit ESP-Magic-Byte `0xE9`; der reale
OTA-Ablauf auf Hardware ist noch nicht getestet (Stand Bridge 0.5.0).

**Funk-Update der Badges auslösen (ab Bridge 0.5.0):**
`{"cmd":"badge_ota","seq":51,"pkt":"<base64, 54 Byte>"}` — das fertige, von der App signierte Auslösepaket
(Modus 13). Die Bridge prüft nur Länge, Magic-ID und Modus, sendet das Paket 3× per ESP-NOW und antwortet mit
`ack`; den Schlüssel kennt sie nicht. Während eines Bridge-Updates antwortet sie mit `err` `busy: ota`.

## Bridge-Update über das Dashboard (`/bridge-update`, ab App 0.2.0 / Bridge 0.3.0)

Die Bridge hat kein WLAN/Ethernet — ihr Firmware-Update läuft per UART-OTA über das bestehende
USB-Kabel aus der Web-UI (anderer Weg als die Basisstation, die per HTTP-Upload in ihrer eigenen
Web-UI aktualisiert wird). Die Seite ist im Dashboard-Header verlinkt, der auch die Bridge-Version
zeigt (aus dem `fw`-Feld des `pong`, `?` bei Bridge < 0.3.0).

**Voraussetzungen:**
- App ≥ 0.2.0 und Bridge-Firmware ≥ 0.3.0 (ältere Bridges melden weder Version noch OTA-Zustand)
- Neues Partition-Schema `min_spiffs` auf der Bridge — bei einem bestehenden Gerät zuerst **einmalig
  per USB flashen** (siehe „Bridge flashen (einmalig)“), sonst schlägt `Update.begin` fehl und die
  Seite zeigt die Fehlermeldung

**Datei:** die Sketch-`.bin` aus dem Build (≈ 900 kB, z. B. `esp32_bridge.ino.bin`, erzeugt mit
`arduino-cli compile --export-binaries herz_schwarm_nerves/firmware/esp32_bridge/`) — **nicht** die
`.merged.bin` und nicht den Bootloader. Max. 2 MB, Formatprüfung: ESP-Magic-Byte `0xE9`.

**Ablauf:** Datei auswählen → „▶ Update starten“. Die App überträgt strikt sequenziell in 96-Byte-Chunks
(immer genau ein offenes Kommando, Zuordnung über `seq`): 1000 ms Timeout pro Chunk, max. 3 Wiederholungen,
danach automatischer Abbruch (`ota_abort`); `ota_begin` und `ota_end` haben 20 s Timeout ohne Wiederholung;
Gesamt-Timeout 10 min. Der Fortschrittsbalken zeigt Prozent + Bytes. Grobe Faustregel laut Implementierer:
~5–7 kB/s → ca. **2,5–4 min** für ein ~900 kB-Image. Nach `ota_end` startet die Bridge neu, die App
verbindet sich über ihre normale Reconnect-Logik wieder.

**⚠️ Während des Updates die Bridge nicht vom Strom trennen.**

**Abbruch / Fehler:** „⏹ Abbrechen“ sendet `ota_abort` (Zustand sofort `idle`). Verbindungsabbruch oder
Timeout zeigt die Seite als Fehlermeldung; das verwaiste Update räumt die Bridge nach 30 s ohne Verkehr
selbst zurück (`Update.abort`) — danach sind Effekte wieder möglich, ein USB-Neustart ist nur nötig, wenn
die Bridge selbst nicht mehr hochkommt.

**⚠️ Sicherheitshinweis:** Die Update-Seite hat **keinen Login** — jeder, der die App im Netz erreicht,
kann eine Bridge-Firmware hochladen und flashen. Die App nur in einem vertrauenswürdigen Netz betreiben
oder den Zugriff auf Netzwerkebene beschränken (Firewall/VPN/LAN-Segment); einen Login gibt es bewusst
noch nicht — im Gegensatz zur OTA der Basisstation, die HTTP Basic Auth nutzt.

## Badge-Update per Funk (`/badge-update`, ab App 0.3.0 / Bridge 0.5.0 / Badge 1.7.0)

Die Badges laden ihre Firmware selbst per WLAN von der App; die App löst das über die Bridge per Schwarm-Funk
aus. **Stand: in der CI getestet, am Gerät noch nicht.** Ablauf aus Sicht der Badges, Einrichtung von
`ota_secret.h` und Grenzen: `../README.md` → *Funk-Update der Badges*.

**Voraussetzungen auf der App-Seite:**
- Umgebungsvariable `BADGE_OTA_KEY` — exakt derselbe Text wie `OTA_KEY` in der `ota_secret.h` der Badges
  (alternativ `config :herz_schwarm, :badge_ota_key`). Ohne Schlüssel zeigt die Seite einen Hinweis und sendet nichts.
- Bridge-Firmware ≥ 0.5.0 (kennt das Kommando `badge_ota`).
- Die Badges müssen den App-Rechner in ihrem Update-WLAN unter der angegebenen Adresse und dem Port erreichen.

**Datei:** die Badge-`.bin` aus einem Build **mit** `ota_secret.h`
(`arduino-cli compile --fqbn esp32:esp32:esp32s3 --build-path build_ota .` →
`build_ota/Herz_Schwarm_CCC_V.ino.bin`). Geprüft werden Endung `.bin`, ESP-Magic-Byte `0xE9`, höchstens
1 310 720 Byte (App-Slot der Badges) und der Versions-Marker `HERZFW:x.y.z;` im Binary — fehlt er, lehnt die App
die Datei ab. Die Datei liegt danach als `badge.bin` im Verzeichnis `:badge_ota_dir`
(Standard `~/.local/share/herz-schwarm`) und bleibt über einen Neustart der App erhalten.

**Ablauf:** Datei ablegen → die Seite zeigt Version, Größe und MD5 → Adresse (Vorschlag: die eigenen
IPv4-Adressen des Rechners) und Port (Standard 4000) prüfen → „Update an alle Badges senden“. Die App baut das
54-Byte-Paket, signiert es (HMAC-SHA256, auf 8 Byte gekürzt) und schickt es als `badge_ota` an die Bridge. Die
Badges holen die Datei dann unter `GET /firmware/badge.bin`.

**Im IEx:**
```elixir
HerzSchwarm.BadgeOta.info()                              # abgelegte Firmware oder nil
HerzSchwarm.BadgeOta.key_configured?()                   # Schlüssel gesetzt?
HerzSchwarm.BadgeOta.trigger({192, 168, 4, 10}, 4000)    # Auslöser senden
```

**⚠️ Sicherheitshinweis:** Auch diese Seite hat keinen Login. Wer die App erreicht, kann eine Datei ablegen
und ein Update auslösen — die App signiert mit dem hinterlegten Schlüssel. Außerdem ist `/firmware/badge.bin`
für jeden im Netz abrufbar, und die Datei enthält WLAN-Passwort und `OTA_KEY` der Badges im Klartext. Die App
deshalb nur in einem vertrauenswürdigen Netz betreiben.

## Production-Build (für Raspberry Pi 4)

```bash
export MIX_TARGET=rpi4
mix deps.get
mix firmware
# → ./_build/rpi4/dev/nerves/images/herz_schwarm.fw
```

Image auf SD-Karte flashen:
```bash
mix burn
# SD-Karte einlegen, warten bis fertig
```

Aber: **dieser Workflow wird derzeit nicht genutzt** — der Mac reicht für Entwicklung und Test, und im Betrieb läuft die App als normale Phoenix-App auf Raspberry Pi OS (nächster Abschnitt).

## Betrieb auf dem Raspberry Pi (ohne Nerves)

Die App läuft auch als **normale Phoenix-App auf Raspberry Pi OS** (Debian 13, aarch64, getestet auf Pi 4) —
**kein Nerves-Firmware-Flash, keine SD-Karten-Neuinstallation**. Nerves ist hier nur eine target-only-Dep und
wird übersprungen; gebaut wird direkt auf dem Pi.

### 1. Werkzeugkette installieren

```bash
sudo apt-get install -y elixir erlang-dev build-essential git rsync ca-certificates curl inotify-tools
# liefert Elixir 1.18 / OTP 27 — das Projekt verlangt nur ~> 1.15, passt also
```

### 2. Mix-Archiv `nerves_bootstrap` (Pflicht)

```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex nerves_bootstrap "~> 1.13" --force
```

**Ohne dieses Archiv schlägt jedes `mix`-Kommando fehl**, weil `mix.exs`
`archives: [nerves_bootstrap: …]` deklariert. `MIX_TARGET` bleibt ungesetzt (kein Nerves-Build).

### 3. Projekt kopieren und bauen

```bash
# Vom Mac aus — ohne _build/deps/.git/Env-Dateien:
rsync -av --exclude _build --exclude deps --exclude .git --exclude '.env*' \
  herz_schwarm_nerves/ blink@<Pi-IP>:~/herz_schwarm_nerves/

# Auf dem Pi:
cd ~/herz_schwarm_nerves
mix deps.get
MIX_ENV=prod mix compile
mix assets.setup
mix assets.deploy    # Tailwind/Esbuild laden dabei ihre linux-arm64-Binaries
```

### 4. Umgebungsvariablen

`~/.config/herz-schwarm/herz-schwarm.env` (mit `chmod 600`):

```bash
SECRET_KEY_BASE=<lang — z. B. erzeugt mit: MIX_ENV=prod mix phx.gen.secret>
PHX_HOST=<Pi-IP>
PORT=4000
# nur für das Funk-Update der Badges: derselbe Text wie OTA_KEY in der ota_secret.h der Badges
BADGE_OTA_KEY=<langer zufälliger Schlüssel>
```

### 5. systemd-Unit

`/etc/systemd/system/herz-schwarm.service`:

```ini
[Unit]
Description=Herz-Schwarm (Phoenix-App)
After=network-online.target

[Service]
User=blink
WorkingDirectory=/home/blink/herz_schwarm_nerves
Environment=MIX_ENV=prod
EnvironmentFile=/home/blink/.config/herz-schwarm/herz-schwarm.env
ExecStart=/usr/bin/mix phx.server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now herz-schwarm
```

**Warum `mix phx.server` statt `mix release`:** `mix release` funktioniert in diesem Projekt nicht — die
`releases:`-Konfiguration in `mix.exs` ist Nerves-spezifisch, es entsteht kein startbares Release.

### 6. Bridge per USB am Pi

- Nutzer in Gruppe `dialout`: `sudo usermod -aG dialout <user>` (danach neu anmelden bzw. Dienst neu starten)
- Die App findet den Port per Auto-Detect (`/dev/ttyACM0` bei nativem USB-CDC, z. B. ESP32-C3)
- Bei Bedarf fest vorgeben: `UART_DEVICE=/dev/ttyACM0` in die Env-Datei setzen
- Bridge von hier aus flashen: siehe „ESP32-C3 flashen (die Bridge am Raspberry Pi)“

### 7. Nach Code-Änderungen

```bash
# erneut rsync wie in Schritt 3, dann auf dem Pi:
MIX_ENV=prod mix compile
mix assets.deploy                       # nur bei Asset-Änderungen
sudo systemctl restart herz-schwarm
```

### Erreichbar

| URL | Zweck |
|-----|-------|
| `http://<Pi-IP>:4000/` | Dashboard (Effekte, Tap-Counter) |
| `http://<Pi-IP>:4000/diagnose` | Monitoring / Diagnose |
| `http://<Pi-IP>:4000/bridge-update` | Bridge-OTA über UART |
| `http://<Pi-IP>:4000/badge-update` | Funk-Update der Badges auslösen |
| `http://<Pi-IP>:4000/firmware/badge.bin` | abgelegte Badge-Firmware (laden die Badges beim Funk-Update) |

Daten der App liegen unter `~/.local/share/herz-schwarm/` (`taps.json`, `badge.bin`).

## Tests / IEx

```bash
# IEx-Konsole mit geladener App
iex -S mix phx.server

# Im IEx:
alias HerzSchwarm.{Bridge, EffectEngine, PeerTracker}
Bridge.connected?()
EffectEngine.trigger_effect(5)  # Beat
EffectEngine.set_bpm(120)
EffectEngine.stop_all()
```

Automatische Tests: `mix test` (läuft ohne Bridge und ohne Hardware; in der CI bei jedem Push und Pull Request).

## Was NICHT funktioniert auf Mac

- **Nerves-Firmware-Build** (`mix firmware`, `mix burn`) — das geht nur mit `MIX_TARGET=rpi4` und cross-compile. Auf Mac nicht versuchen.
- **Nerves-Pack** — gleiche Einschränkung.

## Troubleshooting

### `mix deps.get` schlägt fehl
- Hex-Version prüfen: `mix hex.info`
- Repo: `mix hex.repo remove hex; mix hex.repo add hex https://repo.hex.pm`

### `mix phx.server` zeigt nichts im Browser
- `check_origin: false` ist in `dev.exs` gesetzt — sollte gehen
- Firewall: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/elixir`
- `http://127.0.0.1:4000` statt `localhost` versuchen

### UART-Bridge verbindet nicht
- `ls /dev/cu.*` zeigt das Device?
- ESP32-Bridge-Sketch korrekt geflasht? (115200 Baud, newline JSON)
- Log zeigt `Keine ESP32-Bridge gefunden` → Bridge antwortet nicht auf `status` (falsche Firmware/Baudrate?)
- Mit `config :logger, level: :debug` zeigt `Bridge-Probe <port>: …` jeden geprüften Port
- Notfalls Port fest vorgeben: `UART_DEVICE=/dev/cu.usbmodem101 mix phx.server`
- Logs prüfen: `[debug] Reconnect scheduled in 2000ms` → Bridge ist im Reconnect-Loop

### `circuits_uart` Permission denied
- macOS: `sudo chmod 666 /dev/cu.usbmodem101` (für Dev)
- Oder User zu `dialout`-Gruppe hinzufügen (Linux, nicht macOS-relevant)

### `Plug.Cowboy.Translator.translate/4 is undefined`
- Behoben in App 0.1.2: Ursache war, dass `config/*.exs` nie geladen wurde (`loadconfig`-Alias in
  `mix.exs` rief den Task nicht auf) → Phoenix fiel auf Cowboy zurück. Jetzt Bandit als Dep, Cowboy raus.
- Tritt es wieder auf: `mix deps.unlock --unused && mix deps.clean --unused --unlock`

### C6-USB-Probleme
- **ROM-Bootloader (PID 0x1001) sichtbar statt USB-CDC**: Reset-Taste drücken, USB-Cabel kurz ziehen
- **Port verschwindet zwischen Runs**: Mac-USB-Energie-Management, USB-Hub mit eigener Stromversorgung verwenden
- **C6 antwortet nicht auf JSON**: Baud-Rate prüfen (115200), Boot-Message "bridge ready" sollte kommen

## Bekannte Bugs (Stand App 0.3.0 / Bridge 0.5.0)

Offen: **Bandit 1.12.5** — HTTP/2-Advisory EEF-CVE-2026-105659 ist ungefixt, deshalb ist HTTP/2 in
`config/config.exs` abgeschaltet (`http_2_options: [enabled: false]`). Bei einem Fix Bandit aktualisieren und
die Zeile entfernen.

Noch nicht am Gerät getestet: Bridge-OTA über `/bridge-update`, Funk-Update der Badges über `/badge-update`
(Prüfpunkte in `../todo.md`).

Geändert in App 0.2.1 / 0.2.2: Beat-Takt läuft auf einem festen Raster (kein Wegdriften mehr); Effekt-Kennungen
sind zufällig im Bereich 100001…2³²−1 statt eines Zählers, der nach einem Neustart wieder von vorn begann;
„Alle stoppen“ trägt eine eigene Kennung.

Behoben ab App 0.2.0 / Bridge 0.4.0 / Badge 1.5.0: BPM-Slider und Ambient-Farbwähler änderten nichts an den
Effekten (`phx-change` feuert auf Einzel-Inputs nur innerhalb eines Formulars — die Regler sind jetzt in
einem `form`/`field` mit `phx-change` gebunden); Effekte laufen endlos bis zum Stopp (Knopf „Alle Effekte
auf den Badges stoppen“, Modus 12); Tap-Zähler Kette Badge → `{"evt":"tap",…}` → Dashboard-Karte
„Tap-Counter“; LED-Farbordnung am Badge ist RGB (nicht BGR/GRB). Die Farbabnahme selbst (Rot/Blau an den
1.5.0-Badges) ist im Feld noch zu prüfen.

Behoben in 0.1.2: Bridge-Port-Default `/dev/ttyUSB0` / falscher `usbmodem*`-Port (jetzt status/pong-Probe),
Plug.Cowboy-Translator-Crash (Config wurde nicht geladen, jetzt Bandit), Abziehen der Bridge wurde nicht
erkannt (falsches `circuits_uart`-Nachrichtenformat).

Ebenfalls 0.1.2: Upgrade auf Phoenix 1.8 / LiveView 1.2 / phoenix_html 4 — die Templates nutzen
`{…}`-Interpolation, die LiveView 0.20 nicht kannte (UI zeigte `{@inner_content}` wörtlich). CSS jetzt
Tailwind 4 (`@import "tailwindcss"`, keine `tailwind.config.js`).

1. **Tailwind-4-Binary auf macOS** wird mit Exit 137 beendet (ungültige Ad-hoc-Signatur):
   `codesign --force --sign - _build/tailwind-macos-arm64-*` und `mix assets.build` erneut.
2. **C6 USB-Cable-Reset**: Port-File bleibt erhalten, aber USB-Bus verschwindet
   - **Workaround**: USB-Hub mit eigener Stromversorgung verwenden
