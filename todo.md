# Todo / Notizen (Projekt Herz-Schwarm)

Stand: 2026-10-20 — Badge 1.5.0, Basisstation 0.4.0, Bridge 0.4.0, Nerves-App 0.2.0, Flash-Tooling 0.1.0 (Versionen aller Module: README → *Versionen aller Module*).

## Offen

- **Restliche Badges auf 1.5.0 flashen:** Stand: 2 von 12 auf 1.5.0, eines auf 1.4.1. Dann mit vielen Badges
  in verschiedenen Abständen prüfen, ob die Welle sichtbar von Basis/Bridge nach außen läuft.
- **Endlose Effekte + „Alle stoppen" im Feld testen:** Effekte laufen endlos bis zum Stopp; Knopf „Alle Effekte
  auf den Badges stoppen" (Modus 12) im Nerves-Dashboard testen und prüfen, dass der Stopp auch bei Badges
  **ohne direkte Basisnähe** wirkt (begrenzte Stopp-Weiterleitung über Badges: max. 3 Sendungen, ~60 ms Abstand,
  danach 1000 ms Sperre); dieselbe Welle (gleiche `virusID`) zündet danach nicht wieder, ein neuer Start
  (neue `virusID`) läuft normal an.
- **Tap-Counter im Feld testen:** Kette Badge-Zähler → SyncPacket → Bridge-Event `tap` (nur bei neuem Maximum)
  → Dashboard-Karte. Besonders das Verhalten nach Badge-Neustart prüfen: Zähler startet bei 0, die App
  ignoriert Werte unter dem bisherigen Maximum, bis der Badge wieder darüber liegt.
- **Farbprüfung Rot/Blau:** LED-Farbordnung ist jetzt RGB — an den 1.5.0-Badges prüfen, dass Rot und Blau
  korrekt erscheinen.
- **Nerves-App** (`herz_schwarm_nerves/`, Details in `MAC_SETUP.md` → *Bekannte Bugs*):
  - Bandit 1.12.5: HTTP/2-Advisory EEF-CVE-2026-105659 ungefixt → HTTP/2 per Config aus; bei Fix updaten.
- **Bridge-OTA real testen:** Das einmalige USB-Flashen mit dem neuen Partition-Schema (`min_spiffs`,
  `sketch.yaml` — ohne OTA-Slot schlägt `Update.begin` fehl) ist am Pi erledigt (0.4.0 per esptool).
  Offen bleibt das erste reale OTA über `/bridge-update` (~2,5–4 min für ~900 kB). Dazu die Szenarien prüfen: „Abbruch“
  (Update-Seite zeigt Fehler/ungeklärten Zustand) und „Verbindungsabbruch“ (30-s-Idle-Timeout in der Bridge,
  danach sind Effekte wieder möglich).
- **Morse-Easter-Eggs:** bisher nur `-.-.` (Virus). Ideen: `...` → Regenbogen, `.-..` → Welle.
- **Morse-Virus läuft jetzt endlos:** bewerten, ob das im Betrieb so bleiben soll.
- **Reichweite:** Badges kommen an der Basisstation oft nur mit −85 … −95 dBm an. Station/Bridge senden
  seit 0.3.0/0.1.6 mit 21 dBm; Badges bleiben wegen Hitze bei 13 dBm. Falls nötig: ESP-NOW Long-Range-Modus
  (`WIFI_PROTOCOL_LR`) — müsste auf **allen** Geräten gleichzeitig umgestellt werden.

## Erledigt (Auszug)

- Welle läuft von der Basis nach außen (RSSI des Wellen-Pakets statt smoothRSSI, Hop-Verzögerung, gemeinsamer Wellenstart), 1.4.0.
- Schwarm-Puls wirklich synchron (gemeinsamer Phasen-Zähler statt lokalem `millis()`), 1.2.2.
- Core-übergreifende Races in Badge und Basisstation, 1.2.3 / 0.2.2.
- Basisstation: Modi 1–8, mDNS `herz-base.local`, `no_fs`-Partition (OTA-fähig), OTA-Upload, „Badge finden“.
- Bridge: implizites Ack über Badge-SyncPackets, `CDCOnBoot=cdc` per `sketch.yaml`, ArduinoJson 7.
- Morse-Eingabe als `char[]` (kein `String`).
- Nerves 0.1.2: Config wird wieder geladen, Bandit statt Cowboy, Bridge-Port per status/pong-Probe,
  Phoenix 1.8 / LiveView 1.2 / Tailwind 4 (UI rendert wieder), Badge-Liste + „Badge finden“ (Bridge 0.2.0).
- Bridge: UART-OTA implementiert (Bridge 0.3.0 / App 0.2.0, Dashboard-Seite `/bridge-update`) — Hardware-Test offen.
- Badges: Effekte laufen endlos bis zum Stopp, Modus 12 „Alle Effekte auf den Badges stoppen" (1.5.0, App 0.2.0).
- Tap-Counter komplette Kette: Badge-Zähler im SyncPacket → Bridge-Event `{"evt":"tap",…}` (nur bei neuem
  Maximum, Bridge 0.4.0) → Dashboard-Karte „Tap-Counter" mit Gesamtsumme, Wert je Badge und Reset (App 0.2.0).
- App 0.2.0: BPM-Slider und Ambient-Farbwähler in ein Formular gebunden (`phx-change` feuert wieder —
  vorher änderten die Regler nichts).
- Badge: LED-Farbordnung ist RGB (nicht BGR/GRB).
- Bridge am Pi per USB (esptool) auf 0.4.0 geflasht; Basisstation per OTA auf 0.4.0.
- App auf dem Raspberry Pi deployt — normale Phoenix-App ohne Nerves, als systemd-Dienst `herz-schwarm`
  (Anleitung: `MAC_SETUP.md` → *Betrieb auf dem Raspberry Pi (ohne Nerves)*).

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
