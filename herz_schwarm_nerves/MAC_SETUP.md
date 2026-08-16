# Nerves-Controller auf macOS starten (Development)

Der Nerves-Controller ist für **Raspberry Pi 4** als Nerves-Firmware-Image gedacht. Du kannst die gleiche Code-Basis aber **auf dem Mac als normale Elixir/Phoenix-App** laufen lassen — ohne Nerves-Build, ohne SD-Karte. Das ist ideal zum Entwickeln und Testen der Web-UI.

## Voraussetzungen (einmalig)

```bash
# Elixir + Erlang (via Homebrew, deklarativ ueber nix-homebrew)
brew install elixir

# Asdf-Alternative (Version Manager, empfohlen)
brew install asdf
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 26.2.5
asdf install elixir 1.17.0
asdf global erlang 26.2.5
asdf global elixir 1.17.0
```

Prüfen:
```bash
elixir --version
# Elixir 1.17.0 (compiled with Erlang/OTP 26)
```

## Setup (einmalig pro Repo)

```bash
cd /Users/silvanwalker/Documents/Arduino/Herz_Schwarm_CCC_V/herz_schwarm_nerves

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
arduino-cli compile --fqbn esp32:esp32:esp32s3 \
  herz_schwarm_nerves/firmware/esp32_bridge/

arduino-cli upload -p /dev/cu.usbmodem14101 \
  --fqbn esp32:esp32:esp32s3 \
  herz_schwarm_nerves/firmware/esp32_bridge/
```

Der Port `/dev/cu.usbmodem14101` ist exemplarisch — `arduino-cli board list` zeigt deinen echten. **Sicherstellen, dass der ESP32 kein Badge-Sketch drauf hat**, sondern die `esp32_bridge.ino`.

## App starten

```bash
cd herz_schwarm_nerves

# Auto-detect: nimmt /dev/cu.usbserial-1410 (ESP32-S3 USB-CDC)
# oder /dev/ttyUSB0 (Linux) wenn nichts gefunden
mix phx.server

# Oder mit explizitem Port:
UART_DEVICE=/dev/cu.usbmodem14101 mix phx.server
```

Browser: `http://localhost:4000`

## UART-Device auf Mac

ESP32-Bridge erscheint als USB-Serial-Gerät. Mögliche Pfade:

| Pfad | Typischer Chip |
|------|----------------|
| `/dev/cu.usbserial-1410` | ESP32-S3 native USB-CDC |
| `/dev/cu.usbmodem14101` | ESP32 mit CH340 USB-Serial |
| `/dev/cu.SLAB_USBtoUART` | ESP32 mit CP210x |
| `/dev/cu.wchusbserial*` | ESP32 mit CH340 (chinesische Boards) |

**Finden:**
```bash
ls -la /dev/cu.usb* /dev/cu.wch* /dev/cu.SLAB* 2>/dev/null
# oder
ioreg -p IOUSB -l | grep -i "usb serial\|usb-serial"
```

**Default-Logik** (in `config/dev.exs`):
1. `UART_DEVICE` env-var (höchste Priorität)
2. macOS: prüft `/dev/cu.usbserial-1410` und `/dev/cu.SLAB_USBtoUART`
3. Fallback: `/dev/ttyUSB0` (für Linux-Dev)

## Was die App auf dem Mac macht

| Komponente | Verhalten auf Mac |
|------------|-------------------|
| Phoenix.PubSub | läuft lokal |
| `HerzSchwarm.Bridge` | öffnet `/dev/cu.usbserial-1410` (115200 Baud) |
| `HerzSchwarm.EffectEngine` | läuft im Speicher |
| `HerzSchwarm.PeerTracker` | hört auf Bridge-Events |
| LiveView Web-UI | `http://localhost:4000` |

**Effekte gehen über die USB-Bridge per JSON raus** → Bridge sendet ESP-NOW-Broadcast auf Kanal 13 → alle Badges empfangen das. **Gleicher Kanal wie die ESP32-S3-Basisstation** — sie koexistieren (beide senden `magic_id = 0x421337CC`).

## Coexistenz mit der ESP32-S3-Basisstation

| Komponente | Kanal | Wer? |
|------------|-------|------|
| Basisstation (ESP32-S3+W5500) | 13 | hört passiv, sendet bei Effekt-Trigger |
| Nerves-Bridge (ESP32+Mac) | 13 | hört passiv, sendet bei Effekt-Trigger |
| Badges | 13 | hören passiv auf beide |

**Mögliches Problem:** Wenn beide Stationen gleichzeitig senden, Race auf `virusID` (zufällig, sollte kollisionsfrei sein). Wenn beide gleichzeitig ein Heartbeat-SyncPacket senden, wird eines das andere überschreiben. **In der Praxis kein Problem** weil:
1. Badges senden Heartbeats, Stationen nicht
2. Effekte sind manuelle Trigger, koordiniert via Mensch

**Wenn Probleme:** Eine Station deaktivieren (z. B. Web-UI der ESP32-S3-Basisstation nicht benutzen, nur Nerves verwenden, oder umgekehrt).

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

## Was NICHT funktioniert auf Mac

- **Nerves-Firmware-Build** (`mix firmware`, `mix burn`) — das geht nur mit `MIX_TARGET=rpi4` und cross-compile. Auf Mac nicht versuchen.
- **Nerves-Pack** — gleiche Einschränkung.

## Production-Build (für Raspberry Pi)

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

Aber: **dieser Workflow ist hier selten nötig** — der Mac als Host reicht für Dev + Test, die ESP32-S3+W5500-Variante ist im Produktiv-Einsatz bewährt.

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
- Anderen Port versuchen: `UART_DEVICE=/dev/cu.usbmodem14101 mix phx.server`

### `circuits_uart` Permission denied
- macOS: `sudo chmod 666 /dev/cu.usbserial-1410` (für Dev)
- Oder User zu `dialout`-Gruppe hinzufügen (Linux, nicht macOS-relevant)

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

## Bridge-Firmware flashen (C6 / ESP32 / ESP32-S3)

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

4. **Verifizieren** (Serial-Log "bridge ready" sollte erscheinen):

   ```bash
   cat /dev/cu.usbmodem101 | head -5
   # → {"evt":"log","msg":"bridge ready"}
   ```

### C6-Spezifische Hinweise

- **ROM-Bootloader (PID 0x1001)**: Wenn das C6 im Download-Mode hängt, USB-Cabel kurz ziehen + Reset-Taste drücken
- **USB-CDC-Reset beim Serial-Open**: XIAO C6 hat das **nicht** (im Gegensatz zu ESP32-C3)
- **Channel 13** für ESP-NOW: Kanal ist in `esp32_bridge.ino` fest verdrahtet, MAC `0x421337CC`

## App starten auf Mac

### Erste Schritte

```bash
cd herz_schwarm_nerves

# Dependencies
mix deps.get

# Compile (einmalig oder nach Code-Änderungen)
mix compile

# App starten
UART_DEVICE=/dev/cu.usbmodem101 mix phx.server
```

### Auto-Detect (alternativ, ohne env-var)

`config/dev.exs` versucht `Path.wildcard` auf macOS-Pfade:

1. `UART_DEVICE` env-var (höchste Priorität)
2. `/dev/cu.usbserial-*` (ESP32-S3 native USB)
3. `/dev/cu.SLAB_USBtoUART` (CP2102)
4. `/dev/cu.usbmodem*` (XIAO-C6, CH340) — **meistens der richtige**
5. Fallback `/dev/ttyUSB0` (Linux)

**Bekannter Bug**: `Application.get_env(:herz_schwarm, :uart_device, "/dev/ttyUSB0")` in `bridge.ex:45` fängt die Auto-Detect-Resolution **nicht ab** zur Init-Zeit. Workaround: immer `UART_DEVICE=...` explizit setzen.

### Port wechseln ohne Code-Änderung

```bash
# Anderes C6 (anderer USB-Port)
UART_DEVICE=/dev/cu.usbmodem14101 mix phx.server

# Linux-Build (Pi 4)
MIX_TARGET=rpi4 mix phx.server  # nutzt target.exs
```

### Phoenix-Web-UI

- URL: `http://localhost:4000`
- Hauptmenü: 8 Effekt-Buttons, BPM-Slider, Tap-Beat, Ambient-Color-Picker
- Live-Updates via PubSub (kein Polling, WebSocket)
- Bridge-Status + Peer-Count in Header

## UART-Device auf Mac

ESP32-Bridge erscheint als USB-Serial-Gerät. Mögliche Pfade:

| Pfad | Board | Hinweis |
|------|-------|---------|
| `/dev/cu.usbserial-1410` | ESP32-S3 native USB | **bevorzugt** für S3 |
| `/dev/cu.SLAB_USBtoUART` | ESP32 mit CP210x | zuverlässig |
| `/dev/cu.usbmodem14xxx` | ESP32 mit CH340/CH341 | häufigste China-Boards |
| `/dev/cu.wchusbserial*` | ESP32 mit CH340 (WCH-IC) | alternative Bezeichnung |
| `/dev/cu.usbmodem*` | XIAO ESP32C6 native USB-C | **für C6** |

**Finden:**
```bash
ls -la /dev/cu.usb* /dev/cu.wch* /dev/cu.SLAB* 2>/dev/null
# oder
ioreg -p IOUSB -l | grep -i "usb serial\|usb-serial"
```

## Wichtige Constraints

- **macOS first** (GallifreyM1), Linux secondary (x86_64)
- **Windows**: nicht in flashlib v0.1.0 (geplant v0.2.0 — eigener Versions-Track des Flash-Tools, siehe unten)
- **Effekt-Steuerung läuft NUR über diese Web-UI** (oder Basisstation), nie im TUI-Flasher
- **Version**: `Herz_Schwarm_CCC_V.ino` Defines sind nur für die Badge-FW + den `vA.B.C.D`-Git-Tag maßgeblich. Basisstation/Bridge/Nerves-App/flashlib versionieren sich unabhängig — vollständige Tabelle in `../README.md` (Abschnitt "Versionen aller Module")
- **Logs append-only**: `firmware_update_log.csv`/`.md` werden nie überschrieben

## Coexistenz mit der ESP32-S3+W5500-Basisstation

| Komponente | Kanal | Wer? |
|------------|-------|------|
| Basisstation (ESP32-S3+W5500) | 13 | hört passiv, sendet bei Effekt-Trigger |
| Nerves-Bridge (ESP32-C6) | 13 | hört passiv, sendet bei Effekt-Trigger |
| Badges | 13 | hören passiv auf beide |

**Mögliches Problem:** Wenn beide Stationen gleichzeitig senden, Race auf `virusID` (zufällig, sollte kollisionsfrei sein). Wenn beide gleichzeitig ein Heartbeat-SyncPacket senden, wird eines das andere überschreiben. **In der Praxis kein Problem** weil:
1. Badges senden Heartbeats, Stationen nicht
2. Effekte sind manuelle Trigger, koordiniert via Mensch

**Wenn Probleme:** Eine Station deaktivieren (z. B. Web-UI der ESP32-S3-Basisstation nicht benutzen, nur Nerves verwenden, oder umgekehrt).

## Ack/Retry-Mechanismus der Nerves-Bridge (ab Bridge-FW v0.1.2)

Nur der Nerves-Pfad (Modus 3: Matrix + Basisstation + Nerves) hat zuverlässige Zustellung. Modus 2 (Basisstation allein) bleibt bewusst fire-and-forget — dort existiert kein Ack.

**Ablauf:**
1. Bridge broadcastet ein `SyncPacket` (wie bisher).
2. Jede Station, die es empfängt, sendet ein `AckPacket` (magic_id + virusID) per ESP-NOW-Unicast an die Absender-MAC zurück.
3. Haben nicht alle zuletzt aktiven (< 30s) Stationen innerhalb von 150ms geantwortet, broadcastet die Bridge das gleiche Paket erneut — max. 2 Retries (3 Sends insgesamt).
4. Stationen ohne Lebenszeichen seit 30s gelten als offline und blockieren keine Retries mehr.

**Peer-Count:** `{"evt":"pong","peers":N,...}` liefert jetzt die echte Anzahl zuletzt aktiver Stationen (vorher immer `0`, das Feld wurde nie gesetzt). Der Pi pollt `{"cmd":"status"}` alle 5s automatisch (`HerzSchwarm.Bridge`), das Dashboard zeigt den Wert live über `PeerTracker`.

**Für die Stations-Firmware** (separates Repo, nicht hier): nach Empfang eines validen `SyncPacket` ein `AckPacket{magic_id: 0x421337CC, virusID: <empfangene virusID>}` per `esp_now_send()` unicast an die Absender-MAC zurücksenden. Die Bridge-MAC muss dafür einmalig als ESP-NOW-Peer registriert werden (unverschlüsselt, Kanal 13).

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

Aber: **dieser Workflow ist hier selten nötig** — der Mac als Host reicht für Dev + Test, die ESP32-S3+W5500-Variante ist im Produktiv-Einsatz bewährt.

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
- `UART_DEVICE=/dev/cu.usbmodem101 mix phx.server` setzen (umgeht Auto-Detect-Bug)
- Logs prüfen: `[debug] Reconnect scheduled in 2000ms` → Bridge ist im Reconnect-Loop

### Reconnect-Loop auf `/dev/ttyUSB0` (Linux ohne ESP32)
- Setze `UART_DEVICE=` explizit oder installiere `plug_cowboy` neu
- Oder fix in `lib/herz_schwarm/bridge.ex:45`: ersetze `Application.get_env(..., "/dev/ttyUSB0")` durch `Application.fetch_env!(:herz_schwarm, :uart_device)`

### `circuits_uart` Permission denied
- macOS: `sudo chmod 666 /dev/cu.usbmodem101` (für Dev)
- Oder User zu `dialout`-Gruppe hinzufügen (Linux, nicht macOS-relevant)

### `Plug.Cowboy.Translator.translate/4 is undefined`
- `plug_cowboy 2.9.0` ist nicht mit OTP 28 / Elixir 1.18 kompatibel
- Fix: `mix.exs` Dep `{:plug_cowboy, "~> 2.6"}` entfernen (Bandit wird bereits genutzt)

### C6-USB-Probleme
- **ROM-Bootloader (PID 0x1001) sichtbar statt USB-CDC**: Reset-Taste drücken, USB-Cabel kurz ziehen
- **Port verschwindet zwischen Runs**: Mac-USB-Energie-Management, USB-Hub mit eigener Stromversorgung verwenden
- **C6 antwortet nicht auf JSON**: Baud-Rate prüfen (115200), Boot-Message "bridge ready" sollte kommen

## Bekannte Bugs (Stand v1.2.0.3)

1. **Bridge-Init Default-Bug**: `Application.get_env` fällt auf `/dev/ttyUSB0` zurück, Auto-Detect wird ignoriert
   - **Workaround**: `UART_DEVICE=/dev/cu.usbmodem101 mix phx.server`
2. **Plug.Cowboy-Translator-Crash**: sporadisch, abhängig von Logger-Events
   - **Workaround**: `plug_cowboy` Dep aus `mix.exs` entfernen
3. **C6 USB-Cable-Reset**: Port-File bleibt erhalten, aber USB-Bus verschwindet
   - **Workaround**: USB-Hub mit eigener Stromversorgung verwenden
