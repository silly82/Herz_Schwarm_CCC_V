# Todo / Notizen (Projekt Herz-Schwarm)

## Vorerst zurückgestellt

- **Flash / Binary-Größe:** ~900 KB ist für ESP-NOW + WiFi-Stack + Arduino + FastLED normal. Später optional:
  - Morse-Eingabe: `String morseInput` durch kleinen festen `char[]` ersetzen (weniger Overhead, weniger Fragmentierung).
  - Board-Option **Core Debug Level** auf **None** halten (Verbose vergrößert das Binary merklich).
  - Mehr **App-Platz** ohne kleinere `.bin`: anderes **Partition Scheme** (z. B. `huge_app`), falls die 71 %-Anzeige stört — funktional oft unnötig.

## Git / Release

- **`Debug` → `main`:** Erst mergen, wenn auf **Hardware** verifiziert (Primzahl-Logik inkl. eigenes Gerät, Singularity, ESP-NOW, Basisstation + Badges mit neuen `mode` 2/3).

## Kurzreferenz Build

- FQBN: `esp32:esp32:esp32s3`
- Details: `.cursor/rules/arduino-cli.mdc`
- **Nummerierte Gesamt-Doku:** `README.md` → Abschnitt *Projekt-Dokumentation (nummeriert)*.

---

## Basisstation (Umsetzungsstand)

**Sketch:** `Herz_Schwarm_BaseStation/Herz_Schwarm_BaseStation.ino`

1. **Ethernet:** W5500 (Spotpear-Pins wie im Sketch kommentiert), Web auf **:80** nach `ETH_GOT_IP`.
2. **ESP-NOW:** Kanal **13**, passiv Peers sammeln + gezielter Broadcast (`SyncPacket`, Effekte `m=1|2|3`).
3. **Web-UI:** Peers-Tabelle, Osteregg-Buttons, **MQTT-Einstellungen** (Broker, Port, Login, Topics) → **NVS**, Klartext-MQTT ohne TLS.
4. **API:** siehe README (*Projekt-Dokumentation*, Punkte 5–6).

### Noch offen / Ideen

- TLS für MQTT/Web: bewusst **nicht** vorgesehen.
- Home Assistant: nicht nötig; MQTT reicht für Integration nach Bedarf.

### Hardware (Referenz)

- **Gedachtes Board:** [Spotpear — ESP32-S3R8 PoE / RJ45 / W5500 …](https://spotpear.com/wiki/ESP32-S3R8-PoE-ETH-RJ45-Camera-Micro-SD-Pico-W5500-OV2640-OV5640.html) — u. a. **ESP32-S3R8**, Ethernet **W5500 (SPI)**; Pinbelegung im Wiki mit Sketch abgleichen.
- **Technik:** WiFi bleibt für ESP-NOW aktiv; Datenpfad MQTT/Web über Ethernet.

### Recht / Camp

- Sniffing nur im eigenen Aufbau / mit Einverständnis der Beteiligten.
