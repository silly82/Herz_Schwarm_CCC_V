---
name: herz-schwarm
description: "Herz-Schwarm CCC — ESP32-S3 LED-Badge-Schwarm (Firmware, TUI-Flasher, Versionsschema, Build-Pfade). Load when working on Herz_Schwarm_CCC_V repo, flashing badges, TUI tooling, or A.B.C.D versioning."
version: 1.3.0
author: silly82 (Silvan)
license: MIT
platforms: [macos, linux, windows]
metadata:
  hermes:
    tags: [esp32, arduino, herz-schwarm, ccc, led-badge, swarm, esp-now, version, tui, pyserial, arduino-cli]
    related_skills: [ad-hoc-verification, plan, esp32-development, esp32-platformio, dogfood]
---

# Herz-Schwarm CCC — Repo Skill

Synchronisierter LED-Badge-Schwarm für CCC (Waveshare ESP32-S3-Matrix).
ESP-NOW-basiert, Kanal 13, MAGIC_ID `0x421337CC`, 8x8 RGB-Matrix auf GPIO 14,
BOOT-Button auf GPIO 0, Bewegungssensor QMI8658 an GPIO 11/12. Beinhaltet:
Badge-Firmware, Basisstation (ESP32-S3 + W5500), Nerves-Controller
(Elixir/Phoenix) mit USB-Bridge, TUI-Flasher (Python).

Stand 2026-11-12: Badge 1.8.0, Basisstation 0.4.2, Bridge 0.5.0, App 0.3.0,
Flash-Tooling 0.2.1. Maßgeblich sind `README.md` (Funktionen, Protokoll,
Versionen) und `todo.md` (offene Punkte, Tests am Gerät). Badge 1.5.1–1.8.0
sind kompiliert und in der CI geprüft, aber noch nicht am Gerät getestet.

## Quick-Start für AI-Agents

```bash
cd <Repo-Wurzel>   # z. B. ~/Documents/Arduino/Herz_Schwarm_CCC_V

# Versionsschema A.B.C.D siehe unten
./scripts/version.sh current          # aktuelle A.B.C aus .ino (Badge)
./scripts/version.sh all              # Versionen aller 5 Module
./scripts/version.sh next-tag         # naechster Git-Tag (D = Commits)
./scripts/version.sh tag              # annotierten Tag setzen (inkl. Modul-Snapshot)

# TUI-Flasher (effekt-Steuerung laeuft NICHT hier, nur ueber Basisstation)
python3 scripts/flash_gui.py
# oder automatisch via Bash-Skript (TTY + pyserial vorhanden)
./scripts/batch_flash_herz_schwarm.sh

# Tests
cd scripts && python3 -m pytest flashlib/tests/ -v   # 41/41 gruen

# Build verifizieren (Badge; Basisstation/Bridge ohne --fqbn, Optionen aus sketch.yaml)
arduino-cli compile --fqbn esp32:esp32:esp32s3 .
arduino-cli compile Herz_Schwarm_BaseStation
arduino-cli compile herz_schwarm_nerves/firmware/esp32_bridge
```

## CI

`.github/workflows/ci.yml` läuft bei Push auf `main`, Pull Requests und per
`gh workflow run ci.yml --ref <branch>`: kompiliert Badge (Release, Debug, mit
Funk-Update), Basisstation, Bridge; `pytest` für `scripts/`; `mix test` für die
App. Versionen von ESP32-Core und Libraries sind dort festgenagelt.

## Geheimnisse (nie committen)

- `ota_secret.h` im Repo-Root: WLAN-Zugang und `OTA_KEY` für das Funk-Update
  der Badges (Vorlage `ota_secret.h.example`). Ohne die Datei baut die Firmware
  ohne Funk-Update.
- `Herz_Schwarm_BaseStation/ota_secret.h`: OTA-Passwort der Basisstation.
- `build_ota/`: Badge-Binärdatei mit eingebetteten Geheimnissen.
- App: Umgebungsvariable `BADGE_OTA_KEY` (derselbe Text wie `OTA_KEY`).

## Versionsschema A.B.C.D (seit v1.2.0)

| Stufe | Define | Wann | Wo sichtbar |
|-------|--------|------|-------------|
| **A** MAJOR | `FW_VERSION_MAJOR` | Breaking Change | Code + Tag |
| **B** MINOR | `FW_VERSION_MINOR` | Großes Feature | Code + Tag |
| **C** PATCH | `FW_VERSION_PATCH` | Kleines Feature | Code + Tag |
| **D** BUILD | — (kein Define) | **Jeder Commit** | **Nur Git-Tag** (`v1.2.0.5` = 5 Commits) |

**D ist NICHT im Code** — würde Neukompilation bei jedem Commit erfordern.
Tag-Format: `vA.B.C.D` (`scripts/version.sh` rechnet D automatisch).

**Achtung:** `D` zählt *alle* Commits im Monorepo seit dem letzten `vA.B.C`-Tag,
nicht nur Änderungen an der Badge-`.ino`. Ein Tag wie `v1.2.0.7` heisst nicht
zwingend "7. Build der Badge-FW 1.2.0" — es kann auch reine Nerves-/Bridge-Arbeit
sein, ohne dass sich die Badge-FW seit `v1.2.0.0` geändert hat. Der annotierte
Tag-Body listet deshalb seit `version.sh tag`-Erweiterung alle 5 Modul-Versionen
als Snapshot (`scripts/version.sh all`), nicht nur A.B.C der Badge-FW.

**SyncPacket hat nur 17 Byte** — überträgt nur A.B.C + DEBUG_BUILD-Flag, kein D.

## Versionen aller Module (Stand: siehe `scripts/version.sh all`)

| Modul | Datei | Define/Feld | Eigenständig? |
|-------|-------|-------------|----------------|
| Badge | `Herz_Schwarm_CCC_V.ino` | `FW_VERSION_MAJOR/MINOR/PATCH` | treibt `vA.B.C.D`-Git-Tags |
| Basisstation | `Herz_Schwarm_BaseStation/Herz_Schwarm_BaseStation.ino` | `BASESTATION_FW_MAJOR/MINOR/PATCH` | eigener Zähler |
| Bridge | `herz_schwarm_nerves/firmware/esp32_bridge/esp32_bridge.ino` | `BRIDGE_FW_MAJOR/MINOR/PATCH` | eigener Zähler |
| Nerves-App | `herz_schwarm_nerves/mix.exs` | `@version` | eigener Zähler |
| Flash-Tooling | `scripts/flashlib/__init__.py` | `__version__` | eigener Zähler (aktuell 0.2.1) |

Jedes Modul wird unabhängig gebaut/geflasht/deployed und hat einen eigenen
Release-Rhythmus — eine einzelne globale Versionsnummer für alles ist bewusst
nicht das Ziel. Der `vA.B.C.D`-Git-Tag bleibt der Repo-weite Release-Marker,
dokumentiert aber jetzt per Tag-Message den Stand aller 5 Module.

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
  └─ version.sh                     # A.B.C.D Versions-Helper + Cross-Modul-Snapshot (`all`)
firmware_update_log.csv / .md       # Flash-Audit-Trail (alle Tools, append-only)
build_basestation/ build_debug/     # Build-Artefakte (gitignored)
build_batch_gui/                    # TUI-Build-Cache (gitignored)
```

## Effekt-Steuerung: NICHT im TUI

- TUI-Flasher: nur Compile / Upload / MAC-Read / Log
- Effekte (Modi 1–8: Virus, Regenbogen, Primzahl, Welle, Beat, Zone, Ambient, Strobe; 9 Badge finden; 10 Wellen-Stopp; 12 Alle stoppen; 11 ist die Tap-Meldung der Badges; 13 löst das Funk-Update aus, nur App + Bridge):
  - **Web-UI** der Basisstation: `http://<basestation-ip>/` (Port 80)
  - **MQTT**: konfiguriert in NVS der Basisstation, Subscribe auf `herzschwarm/base/cmd/virus`
  - **Nerves-App** (Phoenix, Port 4000) über die USB-Bridge: Dashboard, `/diagnose`, `/bridge-update`, `/badge-update`
- TUI hat **keinen ESP-NOW-Adapter** — bewusst keine Effekt-Steuerung

## Hardware-Setup (Waveshare ESP32-S3-Matrix)

- **Pinout**: interne LED-Matrix = GPIO 14, BOOT-Taste = GPIO 0
- **LED-Reihenfolge**: RGB (`FastLED.addLeds<WS2812B, LED_PIN, RGB>`, am Gerät verifiziert)
- **Bewegungssensor**: QMI8658, I²C SDA GPIO 11 / SCL GPIO 12, Adresse 0x6B (ab Badge 1.8.0, `ENABLE_IMU`)
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
- **Effekt-Steuerung** (Modi 1–8, Wellen-Stopp 10, Alle stoppen 12) identisch zur ESP32-S3-Basisstation — beide nutzen Kanal 13, MAGIC_ID 0x421337CC
- **Auto-Detect UART** auf Mac: `Path.wildcard` auf cu.usbserial-*, cu.SLAB_USBtoUART, cu.usbmodem* (XIAO C6)
- **Reconnect-Backoff** exponential (2s→4s→…→30s) — verhindert Log-Spam bei fehlender Hardware
- **Betrieb**: als normale Phoenix-App auf Raspberry Pi OS (systemd-Dienst `herz-schwarm`, Port 4000), kein Nerves-Build — siehe `MAC_SETUP.md`
- **Funk-Update der Badges**: Modul `HerzSchwarm.BadgeOta`, Seite `/badge-update`, `GET /firmware/badge.bin`, Bridge-Kommando `badge_ota` (ab App 0.3.0 / Bridge 0.5.0)
- **Effekt-IDs**: App vergibt 100001…2³²−1; 1…99999 gehören dem Morse-Virus der Badges
- **Gefixt (v1.2.0.5-v1.2.0.7)**: `/dev/ttyUSB0`-Hardcode-Fallback in `bridge.ex` — jetzt `Path.wildcard`-Auto-Detect + fail-loud statt silent fallback
- **Gefixt**: `plug_cowboy` aus `mix.exs` entfernt (war totes Dependency, Bandit ist der aktive Adapter — `config/config.exs` `adapter: Bandit.PhoenixAdapter`)

## Known Issues / Pitfalls

- **ESP32-S3 Bootloader-Reset nach Upload**: ~3s warten, sonst ist Port busy
  - Fix in v0.1.1: MAC wird direkt aus Upload-Output geparst (`flashlib/mac._parse_mac`)
  - Kein separates `esptool read_mac` mehr nötig
- **arduino-cli nicht im PATH** (macOS Arduino IDE Bundle): `flashlib/build._cli()` hat Fallback-Liste
- **argv[0] muss "compile"/"upload" sein**, nicht "arduino-cli" (sonst: `unknown command "arduino-cli"`)
- **pymalloc beim `f.write()` in flashlib/log.py**: cap prüfen, append-only bleibt
- **MQTT retained messages** können täuschen — `log.append()` nutzt UTC-lokale Zeitstempel

## Test-Strategie

- **41/41 Unit-Tests** in `scripts/flashlib/tests/` (pytest)
- **Ad-hoc-Verifikation** per Skript unter `/tmp/hermes-verify-*.sh` (Cleanup nach Lauf)
- **Hardware-Tests**: nur mit echtem ESP32-S3 möglich
  - Flash-Vergleich: 944 KB App + 19 KB Bootloader + 8 KB Partitions = 971 KB
  - RAM: 46 KB (14% von 320 KB Heap)
  - 3 erfolgreiche Test-Flashes dokumentiert in `firmware_update_log.csv` (18:58, 1.1.0)

## Build-Artefakte und gitignore

`build_debug/`, `build_batch/`, `build_basestation/`, `build_bridge/`, `build_batch_gui/`, `build_ota/`
sind Build-Caches → **alle in `.gitignore`**. `firmware_update_log.{csv,md}` wird
**getrackt** (Audit-Trail), `.bak`-Dateien sind ignored.

## Häufige Befehle

```bash
# Version
scripts/version.sh current         # A.B.C (Badge)
scripts/version.sh all             # Versionen aller 5 Module
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
- **Windows**: TUI ab flashlib v0.2.0 (COM-Ports über pyserial, VT-Mode); Bash-Skripte nur macOS/Linux
- **Effekt-Steuerung läuft über Basisstation** (Web-UI / MQTT) **oder Nerves-App**, nie im TUI
- **Fünf unabhängige Versions-Namensräume** (kein einzelnes Single-source-of-truth mehr): Badge (`FW_VERSION_*`, treibt `vA.B.C.D`-Tags), Basisstation (`BASESTATION_FW_*`), Bridge (`BRIDGE_FW_*`), Nerves (`mix.exs` `@version`), flashlib (`__version__`) — siehe Tabelle in README "Versionen aller Module"
- **Logs append-only**: nie `firmware_update_log.csv` überschreiben

## Wann NICHT weiterarbeiten

- Frag nach, bevor `A` (MAJOR) erhöht wird
- Frag nach, bevor `B` (MINOR) ohne Diskussion erhöht wird
- Bei Effekt-Steuerung: verweisen auf Basisstation (Web/MQTT) oder Nerves-App, nicht TUI
- Stationen senden Hauptversion 0 — daran erkennen Badges sie; Badge-FW nie mit Major 0 bauen
- Bei Breaking Change am SyncPacket: 13-Byte-Legacy-Support erhalten; Paketlängen 17/21/23/54 siehe README „ESP-NOW Paket"
