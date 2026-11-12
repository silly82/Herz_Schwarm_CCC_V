# Todo / Notizen (Projekt Herz-Schwarm)

Stand: 2026-11-12 — Badge 1.8.0, Basisstation 0.4.2, Bridge 0.5.0, Nerves-App 0.3.0, Flash-Tooling 0.2.0 (Versionen aller Module: README → *Versionen aller Module*).

Geflasht und am Gerät geprüft ist bisher nur der Stand bis Badge 1.5.0 (2 von 12 Badges), Basisstation 0.4.0
und Bridge 0.4.0. Alles danach (Badge 1.5.1–1.8.0, Basisstation/Bridge 0.4.1–0.5.0) ist kompiliert und läuft
durch die CI, die App 0.2.1–0.3.0 ist durch `mix test` in der CI geprüft.

## Offen

- **Alle Badges per USB auf 1.8.0 flashen** (Stand: 2 von 12 auf 1.5.0, eines auf 1.4.1). Wer das Funk-Update
  nutzen will, legt vorher `ota_secret.h` an — sonst ist danach wieder USB nötig. Danach Basisstation (OTA) auf
  0.4.2, Bridge (USB oder `/bridge-update`) auf 0.5.0 und die App auf dem Pi auf 0.3.0 bringen
  (`BADGE_OTA_KEY` in die Env-Datei).

- **Bewegungssensor am Gerät testen** (Badge 1.8.0, bisher nur kompiliert): Debug-Build flashen, im Log muss
  `[IMU] QMI8658 gefunden, aktiv` und danach alle 2 s eine Zeile mit `|a|` nahe 1.00 erscheinen. Steht dort
  „Werte unplausibel" oder gar nichts, stimmen Register/Messbereich nicht mit den Annahmen im Sketch überein
  (dann bleibt der Sensor aus, das Badge läuft normal). Danach: Schütteln → Herzflattern (Schwelle
  `IMU_SHAKE_G` nachstellen, falls es beim Gehen/Tanzen dauernd oder nie auslöst) und „Herz immer aufrecht"
  einmessen (README → *Bewegungssensor*), dann `IMU_AUTO_ROTATE` einschalten.

- **Funk-Update der Badges am Gerät testen** (Badge 1.7.0 / Bridge 0.5.0 / App 0.3.0; bisher nur kompiliert
  und in der CI geprüft). Reihenfolge: `ota_secret.h` anlegen, **zwei** Badges per USB mit 1.8.0 flashen,
  Version im Sketch auf 1.8.1 erhöhen und bauen, `.bin` unter `/badge-update` ablegen, auslösen. Prüfen:
  - beide Badges zeigen blau blinkend → blau füllend → grün und melden sich mit 1.8.1 zurück;
  - Badge außerhalb der Bridge-Reichweite bekommt den Auslöser über ein anderes Badge;
  - WLAN aus → rot, Neustart, altes Verhalten, derselbe Auslöser wird nicht erneut versucht;
  - falscher `BADGE_OTA_KEY` in der App → kein Badge reagiert;
  - Auslöser mit gleicher Version → kein Badge reagiert;
  - mit allen Badges: verkraftet das WLAN 20+ gleichzeitige Downloads (sonst `OTA_JITTER_MS` erhöhen).

- **1.6.0 / 0.4.2 / App 0.2.2 am Gerät prüfen** (bisher nur kompiliert, nichts geflasht; `mix test` läuft
  in der CI grün):
  - Badge 1.5.1-Anteil: Frame-Raster wirklich 50 Hz und Sync 20 Hz, Stationen zählen nicht mehr als Peer
    (Primzahl/Singularität bei laufendem Beat prüfen), Regenbogen-Farbton zwischen Badges synchron.
  - Badge 1.6.0: Helligkeit folgt dem **nächsten** Badge (Glättung `NEAR_SMOOTH`/`PEER_RSSI_SMOOTH` nach
    Gefühl nachstellen), Tempo je Modus fest (normal ~58 BPM, Primzahl ~103, Regenbogen ~123);
    ferngesteuerte Effekte mit `FX_BRIGHT` 64 — **Wärme bei Dauer-Ambient in Weiß prüfen**, ggf. senken;
    Morse-Virus endet nach 3 s; „Alle stoppen" und direkt danach ein neuer Effekt → bleibt überall an.
  - Gemischter Schwarm: 1.5.0-Badges leiten „Alle stoppen" ohne Kennung weiter und lassen den
    Morse-Virus endlos laufen — beides ist erst sauber, wenn alle Badges auf 1.6.0 sind.
  - Basisstation/Bridge 0.4.2: senden „Alle stoppen" mit Kennung, vergeben keine IDs im Morse-Bereich
    (1…99999); führen sich gegenseitig nicht mehr in der Badge-Liste (0.4.1).
  - App 0.2.2: Effekt-IDs zufällig (100001…2³²−1) statt Zähler, Beat-Takt ohne Drift.

- **Welle mit vielen Badges prüfen:** in verschiedenen Abständen aufstellen und prüfen, ob die Welle sichtbar
  von Basis/Bridge nach außen läuft.
- **Endlose Effekte + „Alle stoppen" im Feld testen:** Effekte laufen endlos bis zum Stopp; Knopf „Alle Effekte
  auf den Badges stoppen" (Modus 12) im Nerves-Dashboard testen und prüfen, dass der Stopp auch bei Badges
  **ohne direkte Basisnähe** wirkt (begrenzte Stopp-Weiterleitung über Badges: max. 3 Sendungen, ~60 ms Abstand,
  danach 1000 ms Sperre); dieselbe Welle (gleiche `virusID`) zündet danach nicht wieder, ein neuer Start
  (neue `virusID`) läuft normal an.
- **Tap-Counter im Feld testen:** Kette Badge-Zähler → SyncPacket → Bridge-Event `tap` (nur bei neuem Maximum)
  → Dashboard-Karte. Besonders das Verhalten nach Badge-Neustart prüfen: Zähler startet bei 0, die App
  ignoriert Werte unter dem bisherigen Maximum, bis der Badge wieder darüber liegt.
- **Farbprüfung Rot/Blau:** LED-Farbordnung ist jetzt RGB — an allen Badges prüfen, dass Rot und Blau
  korrekt erscheinen.
- **Nerves-App** (`herz_schwarm_nerves/`, Details in `MAC_SETUP.md` → *Bekannte Bugs*):
  - Bandit 1.12.5: HTTP/2-Advisory EEF-CVE-2026-105659 ungefixt → HTTP/2 per Config aus; bei Fix updaten.
  - `/bridge-update`, `/badge-update` und `/firmware/badge.bin` haben keinen Login; die Badge-`.bin` enthält
    WLAN-Passwort und `OTA_KEY`. App nur im vertrauenswürdigen Netz betreiben oder Login nachrüsten.
- **Bridge-OTA real testen:** Das einmalige USB-Flashen mit dem neuen Partition-Schema (`min_spiffs`,
  `sketch.yaml` — ohne OTA-Slot schlägt `Update.begin` fehl) ist am Pi erledigt (0.4.0 per esptool).
  Offen bleibt das erste reale OTA über `/bridge-update` (~2,5–4 min für ~900 kB). Dazu die Szenarien prüfen: „Abbruch“
  (Update-Seite zeigt Fehler/ungeklärten Zustand) und „Verbindungsabbruch“ (30-s-Idle-Timeout in der Bridge,
  danach sind Effekte wieder möglich).
- **Morse-Easter-Eggs:** bisher nur `-.-.` (Virus). Ideen: `...` → Regenbogen, `.-..` → Welle.
- **Git-Tag setzen:** letzter Tag ist `v1.4.0.0`; 1.4.1 bis 1.8.0 sind ungetaggt (`scripts/version.sh tag`,
  sinnvoll nach dem Test am Gerät).
- **Flash-TUI 0.2.0 mit Badges testen:** unter Windows (`COMx`) und macOS je einmal flashen; dabei „gleichzeitig
  flashen“ (Taste `6`) mit 3–4 Boards an einem Hub prüfen. Bisher nur Tests, Menü und Kompilieren geprüft.
- **Alte Branches aufräumen:** `Debug`, `copilot/*`, `feat/pi-flash-station` (prüfen, ob noch gebraucht).
- **Ideen (nicht begonnen):** Schwarm-Simulator für Tests ohne Hardware; gemeinsame Header-Datei für das
  Funkprotokoll (Badge, Basisstation, Bridge führen die Paketdefinition je einzeln); Helligkeit nach
  Chip-Temperatur begrenzen; Tap-Zähler früher speichern.
- **Reichweite:** Badges kommen an der Basisstation oft nur mit −85 … −95 dBm an. Station/Bridge senden
  seit 0.3.0/0.1.6 mit 21 dBm; Badges bleiben wegen Hitze bei 13 dBm. Falls nötig: ESP-NOW Long-Range-Modus
  (`WIFI_PROTOCOL_LR`) — müsste auf **allen** Geräten gleichzeitig umgestellt werden.

## Erledigt (Auszug)

- Bewegungssensor: Schütteln → Herzflattern, „Herz immer aufrecht“ und Abdunkeln in Ruhe als Optionen (1.8.0) — Gerätetest offen.
- Funk-Update der Badges über WLAN, Seite `/badge-update` (Badge 1.7.0, Bridge 0.5.0, App 0.3.0) — Gerätetest offen.
- CI: alle Firmwares kompilieren, `pytest` und `mix test` bei jedem Push/PR (`.github/workflows/ci.yml`).
- Badge 1.6.0: Nähe steuert nur die Helligkeit (nächstes Badge), Tempo je Modus fest, ferngesteuerte Effekte mit
  fester Helligkeit, Morse-Virus endet nach 3 s, „Alle stoppen“ mit Kennung (Basis/Bridge 0.4.2, App 0.2.2) — Gerätetest offen.
- Badge 1.5.1: echtes 50-Hz-/20-Hz-Raster, Stationen zählen nicht als Peer, Regenbogen synchron; App 0.2.1:
  Beat ohne Drift (Basis/Bridge 0.4.1) — Gerätetest offen.
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
- Badge-Funk-Update: `ota_secret.h` im Repo-Root (Vorlage `ota_secret.h.example`, gitignored); Update-Datei mit
  `--build-path build_ota` bauen (gitignored, enthält die Geheimnisse).
- Debug-Build Badge: `--board-options CDCOnBoot=cdc --build-property "compiler.cpp.extra_flags=-DENABLE_SERIAL_DEBUG=1" --build-path build_debug`.
- App-Tests: `mix test` in `herz_schwarm_nerves/`; Flash-Tooling: `python -m pytest` in `scripts/`. Beides läuft in der CI.
- **Nummerierte Gesamt-Doku:** `README.md` → Abschnitt *Projekt-Dokumentation (nummeriert)*.

## Hardware (Referenz)

- **Badge:** Waveshare ESP32-S3-Matrix (4 MB Flash + 2 MB PSRAM im Chip; Bewegungssensor QMI8658 an GPIO 11/12).
  Eigene Akku-Version in Arbeit: `herz_badge/`.
- **Basisstation:** [Spotpear ESP32-S3R8 PoE / RJ45 / W5500](https://spotpear.com/wiki/ESP32-S3R8-PoE-ETH-RJ45-Camera-Micro-SD-Pico-W5500-OV2640-OV5640.html) — Ethernet **W5500 (SPI)**, WiFi nur für ESP-NOW.
- **Bridge:** beliebiger ESP32 mit USB (getestet: ESP32-C3, ESP32-S3; Doku: XIAO ESP32-C6).

## Recht / Camp

- Sniffing nur im eigenen Aufbau / mit Einverständnis der Beteiligten.
