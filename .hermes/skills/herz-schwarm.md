---
name: herz-schwarm
description: "Herz-Schwarm CCC — ESP32-S3 LED-Badge-Schwarm (Firmware, TUI-Flasher, Versionsschema, Build-Pfade). Load when working on Herz_Schwarm_CCC_V repo, flashing badges, TUI tooling, or A.B.C.D versioning."
version: 1.2.0
author: silly82 (Silvan)
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [esp32, arduino, herz-schwarm, ccc, led-badge, swarm, esp-now, version, tui, pyserial, arduino-cli]
    related_skills: [ad-hoc-verification, plan, esp32-development, esp32-platformio, dogfood]
---

# Herz-Schwarm CCC — Repo Skill

Synchronisierter LED-Badge-Schwarm für CCC (Waveshare ESP32-S3-Matrix).
ESP-NOW-basiert, Kanal 13, MAGIC_ID `0x421337CC`, 8x8 GRB-Matrix auf GPIO 14,
BOOT-Button auf GPIO 0. Beinhaltet: Badge-Firmware, Basisstation (ESP32-S3 +
W5500), Nerves-Controller (Elixir/Phoenix), TUI-Flasher (Python).

## Quick-Start für AI-Agents

```bash
cd /Users/silvanwalker/Documents/Arduino/Herz_Schwarm_CCC_V

# Versionsschema A.B.C.D siehe unten
./scripts/version.sh current          # aktuelle A.B.C aus .ino
./scripts/version.sh next-tag         # naechster Git-Tag (D = Commits)
./scripts/version.sh tag              # annotierten Tag setzen

# TUI-Flasher (effekt-Steuerung laeuft NICHT hier, nur ueber Basisstation)
python3 scripts/flash_gui.py
# oder automatisch via Bash-Skript (TTY + pyserial vorhanden)
./scripts/batch_flash_herz_schwarm.sh

# Tests
cd scripts && python3 -m pytest flashlib/tests/ -v   # 25/25 gruen

# Build verifizieren
arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc --build-path build_basestation .
```

## Versionsschema A.B.C.D (seit v1.2.0)

| Stufe | Define | Wann | Wo sichtbar |
|-------|--------|------|-------------|
| **A** MAJOR | `FW_VERSION_MAJOR` | Breaking Change | Code + Tag |
| **B** MINOR | `FW_VERSION_MINOR` | Großes Feature | Code + Tag |
| **C** PATCH | `FW_VERSION_PATCH` | Kleines Feature | Code + Tag |
| **D** BUILD | — (kein Define) | **Jeder Commit** | **Nur Git-Tag** (`v1.2.0.5` = 5 Commits) |

**D ist NICHT im Code** — würde Neukompilation bei jedem Commit erfordern.
Tag-Format: `vA.B.C.D` (`scripts/version.sh` rechnet D automatisch).

**SyncPacket hat nur 17 Byte** — überträgt nur A.B.C + DEBUG_BUILD-Flag, kein D.

## Repo-Layout

```
Herz_Schwarm_CCC_V.ino             # Badge-Firmware (Waveshare ESP32-S3-Matrix)
Herz_Schwarm_BaseStation/          # Basisstation (ESP32-S3 + W5500 Ethernet)
  └─ Herz_Schwarm_BaseStation.ino
herz_schwarm_nerves/               # Nerves/Elixir/Phoenix Controller
  ├─ lib/herz_schwarm/              # Bridge, EffectEngine, PeerTracker
  ├─ lib/herz_schwarm_web/          # LiveView Dashboard
  └─ firmware/esp32_bridge/        # USB-Serial-JSON-Adapter
scripts/
  ├─ batch_flash_herz_schwarm.sh    # Bash-Flasher (default: TUI auto-launch)
  ├─ flash_gui.py                   # TUI Pseudo-GUI (ANSI, pyserial)
  ├─ flashlib/                      # Geteilte Python-Library
  │   ├─ ports.py                   # Port-Discovery (arduino-cli + glob-Fallback)
  │   ├─ build.py                   # arduino-cli wrapper (compile/upload_capture)
  │   ├─ mac.py                     # MAC-Parser (write-flash + read_mac)
  │   ├─ log.py                     # CSV + MD Append-only Logger
  │   └─ firmware.py                # A.B.C aus .ino parsen
  └─ version.sh                     # A.B.C.D Versions-Helper
firmware_update_log.csv / .md       # Flash-Audit-Trail (alle Tools, append-only)
build_basestation/ build_debug/     # Build-Artefakte (gitignored)
build_batch_gui/                    # TUI-Build-Cache (gitignored)
```

## Effekt-Steuerung: NICHT im TUI

- TUI-Flasher: nur Compile / Upload / MAC-Read / Log
- Effekte (Modes 1-8: Virus, Regenbogen, Primzahl, Welle, Beat, Zone, Ambient, Strobe):
  - **Web-UI** der Basisstation: `http://<basestation-ip>/` (Port 80)
  - **MQTT**: konfiguriert in NVS der Basisstation, Subscribe auf `herzschwarm/base/cmd/virus`
- TUI hat **keinen ESP-NOW-Adapter** — bewusst keine Effekt-Steuerung

## Hardware-Setup (Waveshare ESP32-S3-Matrix)

- **Pinout**: interne LED-Matrix = GPIO 14, BOOT-Taste = GPIO 0
- **LED-Reihenfolge**: GRB (FastLED konfiguriert)
- **Backside**: offene Kontakte → **Kapton-Tape Pflicht** vor Inbetriebnahme
- **FQBN**: `esp32:esp32:esp32s3:CDCOnBoot=cdc` (für USB-Serial-Debug)
- **arduino-cli-Pfad** (macOS): `/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli`
  - `flashlib/build.py` und `ports.py` haben PATH-Fallback auf diese Bundle-Pfade

## Bash → TUI-Transition

`scripts/batch_flash_herz_schwarm.sh`:
- **TTY + pyserial installiert** → startet TUI automatisch
- `--no-gui` → erzwingt Bash-Modus
- `--gui` → erzwingt TUI (Fehler wenn nicht möglich)
- `--debug` → CDC + Serial-Debug-Build (`ENABLE_SERIAL_DEBUG=1`)
- `--all-usb` → USB-Heuristik statt `arduino-cli board list`

## Nerves / Elixir Controller (`herz_schwarm_nerves/`)

Alternative zur ESP32-S3-Basisstation: Phoenix/LiveView Web-UI auf Mac (oder Pi),
ESP32 als USB-Serial-JSON-Bridge.

- **Start auf Mac**: siehe `herz_schwarm_nerves/MAC_SETUP.md` (komplette Doku inkl. C6-Flash, Auto-Detect, Troubleshooting, C6-Spezifika)
- **Bridge-Firmware**: `herz_schwarm_nerves/firmware/esp32_bridge/esp32_bridge.ino` (115200 Baud, JSON-newline)
- **GenServer-Architektur**: `Bridge` (UART) → `EffectEngine` (State) → `PeerTracker` (Status) → `DashboardLive` (UI)
- **PubSub-Topics**: `bridge:events`, `effect:state`, `peers:count`
- **Effekt-Steuerung** (Modes 1-8) identisch zur ESP32-S3-Basisstation — beide nutzen Kanal 13, MAGIC_ID 0x421337CC
- **Auto-Detect UART** auf Mac: `Path.wildcard` auf cu.usbserial-*, cu.SLAB_USBtoUART, cu.usbmodem* (XIAO C6)
- **Reconnect-Backoff** exponential (2s→4s→…→30s) — verhindert Log-Spam bei fehlender Hardware
- **Nerves-Production-Build** (Raspberry Pi 4) ist optional — der Mac als Dev-Host reicht
- **Bekannter Bug v1.2.0.3**: `Application.get_env` in `bridge.ex:45` fällt auf hardcoded `/dev/ttyUSB0` Default zurück, Auto-Detect wird ignoriert. Workaround: `UART_DEVICE=/dev/cu.usbmodem101 mix phx.server`. Echter Fix: `Application.fetch_env!` statt `get_env`
- **Bekannter Bug v1.2.0.3**: `plug_cowboy 2.9.0` crasht sporadisch mit `UndefinedFunctionError: Plug.Cowboy.Translator.translate/4` (nicht mit OTP 28 kompatibel). Workaround: `{:plug_cowboy, "~> 2.6"}` aus `mix.exs` entfernen (Bandit wird bereits genutzt)

## Known Issues / Pitfalls

- **ESP32-S3 Bootloader-Reset nach Upload**: ~3s warten, sonst ist Port busy
  - Fix in v0.1.1: MAC wird direkt aus Upload-Output geparst (`flashlib/mac._parse_mac`)
  - Kein separates `esptool read_mac` mehr nötig
- **arduino-cli nicht im PATH** (macOS Arduino IDE Bundle): `flashlib/build._cli()` hat Fallback-Liste
- **argv[0] muss "compile"/"upload" sein**, nicht "arduino-cli" (sonst: `unknown command "arduino-cli"`)
- **pymalloc beim `f.write()` in flashlib/log.py**: cap prüfen, append-only bleibt
- **MQTT retained messages** können täuschen — `log.append()` nutzt UTC-lokale Zeitstempel

## Test-Strategie

- **25/25 Unit-Tests** in `scripts/flashlib/tests/` (pytest)
- **Ad-hoc-Verifikation** per Skript unter `/tmp/hermes-verify-*.sh` (Cleanup nach Lauf)
- **Hardware-Tests**: nur mit echtem ESP32-S3 möglich
  - Flash-Vergleich: 944 KB App + 19 KB Bootloader + 8 KB Partitions = 971 KB
  - RAM: 46 KB (14% von 320 KB Heap)
  - 3 erfolgreiche Test-Flashes dokumentiert in `firmware_update_log.csv` (18:58, 1.1.0)

## Build-Artefakte und gitignore

`build_debug/`, `build_batch/`, `build_basestation/`, `build_bridge/`, `build_batch_gui/`
sind Build-Caches → **alle in `.gitignore`**. `firmware_update_log.{csv,md}` wird
**getrackt** (Audit-Trail), `.bak`-Dateien sind ignored.

## Häufige Befehle

```bash
# Version
scripts/version.sh current         # A.B.C
scripts/version.sh next-tag        # vA.B.C.D-Vorschlag
scripts/version.sh tag             # Tag setzen + pushen

# Build
arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc --build-path build_basestation .
arduino-cli compile --fqbn esp32:esp32:esp32s3 --build-path build_basestation .  # Release (kein Debug)

# Test
cd scripts && python3 -m pytest flashlib/tests/ -v

# Flash
python3 scripts/flash_gui.py       # TUI (empfohlen)
./scripts/batch_flash_herz_schwarm.sh --no-gui --debug  # Bash + Debug-Build

# Verifikation
git log --oneline -10
git tag -l --sort=-version:refname | head -5
tail -5 firmware_update_log.csv
```

## Workflow für neue Features

1. **Plan** in `.hermes/plans/YYYY-MM-DD_HHMMSS-<slug>.md` schreiben (skill: `plan`)
2. TDD: erst Tests in `scripts/flashlib/tests/`, dann Implementierung
3. Build verifizieren: `arduino-cli compile ...`
4. Bei echtem Feature → `B` (MINOR) hoch, z. B. `1.2.0 → 1.3.0`
5. Bei kleinem Fix → `C` (PATCH) hoch, z. B. `1.2.0 → 1.2.1`
6. **Ad-hoc-Verifikation** vor jedem Commit (skill: `ad-hoc-verification`)
7. Commit + `./scripts/version.sh tag` → push

## Cross-Skill Hinweise

- **`ad-hoc-verification`**: nach jedem Code-Change ein `/tmp/hermes-verify-*.sh`-Skript
- **`plan`**: bei größeren Refactors/Features (mehrere Dateien, mehrere Tage)
- **`esp32-development`**: ESP-IDF/PlatformIO/Arduino-CLI-Builds
- **`dogfood`**: TUI selbst testen mit `printf 'q\n' | python3 scripts/flash_gui.py`
- **`requesting-code-review`**: vor Merge in main

## Wichtige Constraints

- **macOS first** (GallifreyM1, arm64), Linux secondary (x86_64)
- **Windows**: v0.2.0 (COM-Ports, VT-Mode aktivieren)
- **Effekt-Steuerung läuft NUR über Basisstation** (Web-UI / MQTT), nie im TUI
- **Single-source-of-truth für Version**: `Herz_Schwarm_CCC_V.ino` Defines → gelesen von allen Tools
- **Logs append-only**: nie `firmware_update_log.csv` überschreiben

## Wann NICHT weiterarbeiten

- Frag nach, bevor `A` (MAJOR) erhöht wird
- Frag nach, bevor `B` (MINOR) ohne Diskussion erhöht wird
- Bei Effekt-Steuerung: verweisen auf Basisstation (Web/MQTT), nicht TUI
- Bei Breaking Change am SyncPacket: 13-Byte-Legacy-Support erhalten
