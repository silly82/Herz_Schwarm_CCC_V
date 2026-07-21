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
│  │   Bridge     │ ◄───────► /dev/cu.usbserial-*    │
│  └──────┬───────┘  115200 Baud                      │
│         │                                            │
└─────────┼────────────────────────────────────────────┘
          │ USB-Kabel
┌─────────▼─────────┐
│  ESP32-Bridge     │  esp32_bridge.ino
│  (USB-Serial)     │  → empfängt JSON via UART
└─────────┬─────────┘  → sendet ESP-NOW Broadcast
          │            (Kanal 13, MAGIC_ID 0x421337CC)
          │ 2.4 GHz ESP-NOW
          ▼
   ┌──────┴──────┐
   │ 8x8 Badges  │  Herz_Schwarm_CCC_V.ino
   │ ESP32-S3    │  → empfängt SyncPacket
   └─────────────┘  → führt Effekt aus
```
