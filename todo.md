# Todo / Notizen (Projekt Herz-Schwarm)

## Vorerst zurückgestellt

- **Flash / Binary-Größe:** ~900 KB ist für ESP-NOW + WiFi-Stack + Arduino + FastLED normal. Später optional:
  - Morse-Eingabe: `String morseInput` durch kleinen festen `char[]` ersetzen (weniger Overhead, weniger Fragmentierung).
  - Board-Option **Core Debug Level** auf **None** halten (Verbose vergrößert das Binary merklich).
  - Mehr **App-Platz** ohne kleinere `.bin`: anderes **Partition Scheme** (z. B. `huge_app`), falls die 71 %-Anzeige stört — funktional oft unnötig.

## Git / Release

- **`Debug` → `main`:** Erst mergen, wenn auf **Hardware** verifiziert (Primzahl-Logik inkl. eigenes Gerät, Singularity, ESP-NOW).

## Kurzreferenz Build

- FQBN: `esp32:esp32:esp32s3`
- Details: `.cursor/rules/arduino-cli.mdc`
