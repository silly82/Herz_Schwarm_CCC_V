# Todo / Notizen (Projekt Herz-Schwarm)

Stand: 2026-10-15 — Badge 1.3.0, Basisstation 0.3.0, Bridge 0.2.0, Nerves-App 0.1.2 (Versionen aller Module: README → *Versionen aller Module*).

## Offen

- **Nerves-App** (`herz_schwarm_nerves/`, Details in `MAC_SETUP.md` → *Bekannte Bugs*):
  - Bandit 1.12.5: HTTP/2-Advisory EEF-CVE-2026-105659 ungefixt → HTTP/2 per Config aus; bei Fix updaten.
- **Morse-Easter-Eggs:** bisher nur `-.-.` (Virus). Ideen: `...` → Regenbogen, `.-..` → Welle.
- **Reichweite:** Badges kommen an der Basisstation oft nur mit −85 … −95 dBm an. Station/Bridge senden
  seit 0.3.0/0.1.6 mit 21 dBm; Badges bleiben wegen Hitze bei 13 dBm. Falls nötig: ESP-NOW Long-Range-Modus
  (`WIFI_PROTOCOL_LR`) — müsste auf **allen** Geräten gleichzeitig umgestellt werden.

## Erledigt (Auszug)

- Schwarm-Puls wirklich synchron (gemeinsamer Phasen-Zähler statt lokalem `millis()`), 1.2.2.
- Core-übergreifende Races in Badge und Basisstation, 1.2.3 / 0.2.2.
- Basisstation: Modi 1–8, mDNS `herz-base.local`, `no_fs`-Partition (OTA-fähig), OTA-Upload, „Badge finden“.
- Bridge: implizites Ack über Badge-SyncPackets, `CDCOnBoot=cdc` per `sketch.yaml`, ArduinoJson 7.
- Morse-Eingabe als `char[]` (kein `String`).
- Nerves 0.1.2: Config wird wieder geladen, Bandit statt Cowboy, Bridge-Port per status/pong-Probe,
  Phoenix 1.8 / LiveView 1.2 / Tailwind 4 (UI rendert wieder), Badge-Liste + „Badge finden“ (Bridge 0.2.0).

## Bewusst nicht vorgesehen

- TLS für MQTT/Web.
- Home-Assistant-Integration (MQTT reicht).

## Kurzreferenz Build

- Badge: `arduino-cli compile --fqbn esp32:esp32:esp32s3 .` bzw. `scripts/batch_flash_herz_schwarm.sh`.
- Basisstation / Bridge: `arduino-cli compile <ordner>` — Board-Optionen kommen aus der jeweiligen `sketch.yaml`
  (Bridge auf ESP32-C3/C6: `--fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc` bzw. `esp32c6`).
- Basisstation-OTA-Passwort: `Herz_Schwarm_BaseStation/ota_secret.h` (Vorlage `ota_secret.h.example`, gitignored).
- **Nummerierte Gesamt-Doku:** `README.md` → Abschnitt *Projekt-Dokumentation (nummeriert)*.

## Hardware (Referenz)

- **Badge:** Waveshare ESP32-S3-Matrix (4 MB Flash + 2 MB PSRAM im Chip).
- **Basisstation:** [Spotpear ESP32-S3R8 PoE / RJ45 / W5500](https://spotpear.com/wiki/ESP32-S3R8-PoE-ETH-RJ45-Camera-Micro-SD-Pico-W5500-OV2640-OV5640.html) — Ethernet **W5500 (SPI)**, WiFi nur für ESP-NOW.
- **Bridge:** beliebiger ESP32 mit USB (getestet: ESP32-C3, ESP32-S3; Doku: XIAO ESP32-C6).

## Recht / Camp

- Sniffing nur im eigenen Aufbau / mit Einverständnis der Beteiligten.
