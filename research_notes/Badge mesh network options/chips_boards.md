# Microcontroller chips and ready-made boards for a battery LED badge swarm (state: October 2026)

Scope: which chip and which off-the-shelf boards fit the Herz-Schwarm badge (ESP-NOW broadcast at 20 Hz, RSSI measurement, radio always listening, 8x8 WS2812), with a choice between staying on ESP32-S3 and moving to another chip. Numbers come from vendor datasheets unless marked otherwise. "Measured" means an independent bench measurement.

Project facts used below (read from the repo, not from the web): the badge sketch `Herz_Schwarm_CCC_V.ino` is built with `arduino-cli` and FQBN `esp32:esp32:esp32s3`. It uses `esp_now.h` plus `FastLED` (WS2812B, 64 LEDs, GPIO14), sets `esp_wifi_set_protocol(WIFI_IF_STA, 11B|11G|11N)`, uses channel 13 and `esp_wifi_set_max_tx_power(52)`, broadcasts every 50 ms (`SYNC_TX_INTERVAL_MS 50`), and does not pin tasks to cores.

---

## Q1. Espressif line-up 2026 (S3, C3, C6, C5, C61, H2, H4, S31, P4): radios, ESP-NOW, currents, sensitivity, TX power, sleep, CPU, LED peripherals, price, toolchains

### Takeaway
Among Espressif's Wi-Fi chips, the radio-on receive current only ranges from about 78 to 88 mA on 2.4 GHz. The ESP32-C6 is the lowest at 78 mA, about 11% below the S3's 88 mA. The ESP32-C5 has the best 2.4 GHz sensitivity (-100.5 dBm at 11b 1 Mbps), but its TX power is 1 dB lower and its 5 GHz receive current is higher (110 mA). Moving between Espressif Wi-Fi chips therefore buys at most about 10-15% battery and 1-2 dB of link budget. The ESP32-H2 has no Wi-Fi and so no ESP-NOW. Its BLE/802.15.4 receive current is 24-25 mA, and it is the only Espressif chip with a large current saving. Arduino-ESP32 supports S3, C3, C5, C6, H2 and P4 out of the box. The C61 needs rebuilt libraries and has no RMT peripheral. ESPHome supports the Arduino framework only on ESP32, C3, S2 and S3; every newer chip is ESP-IDF only there.

### Cited Findings

**Main datasheet table (typical values at 3.3 V, 25 °C; TX is peak at 100% duty; RX with CPU idle):**

| Parameter | ESP32-S3 (DS v2.2) | ESP32-C3 (DS v2.4) | ESP32-C6 (DS v1.5) | ESP32-C5 (DS v1.5) | ESP32-C61 (DS v1.1) | ESP32-H2 (DS v1.3) |
|---|---|---|---|---|---|---|
| Wi-Fi | 2.4 GHz b/g/n | 2.4 GHz b/g/n | 2.4 GHz Wi-Fi 6 (b/g/n/ax) | 2.4 + 5 GHz Wi-Fi 6 (a/b/g/n/ac/ax), one band at a time | 2.4 GHz Wi-Fi 6 | none |
| BLE / 802.15.4 | BLE 5 / no | BLE 5 / no | BLE 5 / yes | BLE 5 / yes | BLE 5 / no | BLE 5 / yes |
| Wi-Fi RX current (11b/g/n HT20) | 88 mA (HT40 91) | 84 mA (HT40 87) | 78 mA (HE20 78, HT40 82) | 87 mA @2.4 GHz; 110 mA @5 GHz | 88 mA | n/a |
| Wi-Fi TX current, 11b 1 Mbps at max power | 340 mA @21 dBm | 335 mA @21 dBm | 354 mA @21 dBm | 320 mA @20 dBm (2.4 GHz); 408 mA @18 dBm 11a 6 Mbps (5 GHz) | 360 mA @21 dBm | n/a |
| BLE RX current | 93 mA | not in DS table found | 71 mA | 79 mA | 81 mA | 24 mA |
| BLE TX current @0 dBm / @max | 176 mA / 335 mA @21 dBm | — | 130 mA / 315 mA @20 dBm | 140 mA / 331 mA @20 dBm | 128 mA / 283 mA @18 dBm | 36 mA / 140 mA @20 dBm |
| 802.15.4 RX current | n/a | n/a | 74 mA | 78 mA | n/a | 25 mA |
| Max Wi-Fi TX (11b) | 21.0 dBm | 21.0 dBm | 21.0 dBm | 20.0 dBm (2.4); 18.0 dBm (5 GHz 11a) | 21.0 dBm | n/a |
| RX sens. 11b 1 Mbps | -98.4 dBm | -98.4 dBm | -99.2 dBm | -100.5 dBm (2.4); 11a 6 Mbps 5 GHz: -94.0 dBm | -99.5 dBm | n/a |
| RX sens. BLE 1 Mbps / 125 kbps coded | -97.5 / -104.5 dBm | -97 / -105 dBm | -98.5 / -106.0 dBm | -98.5 / -106.0 dBm | -98.0 / -106.0 dBm | -99.0 / -106.5 dBm |
| RX sens. 802.15.4 | n/a | n/a | -104 dBm | -104 dBm | n/a | -102.5 dBm |
| BLE TX range | -24 ... +20 dBm | — | -15 ... +20 dBm | -15 ... +20 dBm | -15 ... +20 dBm | -24 ... +20 dBm |
| Light-sleep | 240 µA | 130 µA | 180 µA (35 µA with peripherals off) | 250 µA (60 µA with peripherals off) | 200 µA (50 µA) | 85 µA (25 µA) |
| Deep-sleep | 7 µA (8 µA with RTC periph.) | 5 µA | 7 µA | 12 µA | 10 µA | 7 µA |
| CPU | 2x Xtensa LX7 @240 MHz + ULP | 1x RISC-V @160 MHz | 1x RISC-V @160 MHz + LP RISC-V @20 MHz | 1x RISC-V @240 MHz + LP RISC-V @48 MHz | 1x RISC-V @160 MHz | 1x RISC-V @96 MHz |
| SRAM | 512 KB + 16 KB RTC | 400 KB (16 KB cache) | 512 KB HP + 16 KB LP | 384 KB HP + 16 KB LP | 320 KB | 320 KB |
| In-package memory variants | e.g. S3FH4R2 (4 MB flash + 2 MB PSRAM) | C3FH4 etc. | C6FH4 (4 MB), C6FH8 (8 MB), QFN32 5x5 mm | C5HR2, C5HR8, C5HF4, C5NF8R2LA | flash/PSRAM in-package options | H2FH2S, H2FH4S |
| RMT (WS2812 driver) | 4 TX + 4 RX channels | 2 TX + 2 RX | 4 channels (TX/RX) | 2 TX + 2 RX | **no RMT peripheral** | 2 TX + 2 RX |

Sources for the table: [ESP32-S3 datasheet v2.2](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf) (Tables 5-7, 5-8, 5-10, 6-2, 6-4, 6-12, 6-14); [ESP32-C3 datasheet v2.4](https://documentation.espressif.com/esp32-c3_datasheet_en.pdf) (Tables 5-7, 5-9, 6-2, 6-4, BLE RX tables); [ESP32-C6 datasheet v1.5](https://documentation.espressif.com/esp32-c6_datasheet_en.pdf) (Tables 5-7 to 5-11, 6-2, 6-4, 6-12, 6-14, 6-18); [ESP32-C5 datasheet v1.5](https://documentation.espressif.com/esp32-c5_datasheet_en.pdf) (Tables 5-7 to 5-12, 6-2, 6-4, 6-8, 6-10, 6-18, 6-20, 6-24); [ESP32-C61 datasheet v1.1](https://documentation.espressif.com/esp32-c61_datasheet_en.pdf) (Tables 5-6 to 5-9, 6-2, 6-4; the peripheral list contains no RMT entry); [ESP32-H2 datasheet v1.3](https://documentation.espressif.com/esp32-h2_datasheet_en.pdf) (Tables 5-6 to 5-9, 6-6, 6-8, 6-12).

Datasheet caveats:
- The S3 light/deep-sleep figures apply to ESP32-S3 and S3FH8. Espressif notes that PSRAM variants such as the S3FH4R2 (the Waveshare chip) "might be higher" — [ESP32-S3 datasheet](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf).
- The ESP32-C6 datasheet's BLE TX/RX current at 0 dBm (130/71 mA) matches a community comparison citing about 130 mA for the C6 and 102 mA for the C3 for BLE TX @0 dBm — [hubble.com comparison](https://hubble.com/community/comparisons/esp32-c6-vs-esp32-h2-vs-esp32-c3-which-chip-for-ble-only-projects/).

**ESP-NOW per chip and band:**
- The ESP-NOW docs for ESP32-C5 list allowed channels on 2.4 GHz (1-14) and on 5 GHz (36-64, 100-144, 149-177). ESP-NOW on 5 GHz is therefore supported at API level on the C5 — [ESP-IDF ESP-NOW (C5)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html).
- The C5 cannot run both bands at once. 5 GHz is selected with `esp_wifi_set_band_mode(WIFI_BAND_MODE_5G_ONLY)`; the default `WIFI_BAND_MODE_AUTO` scans both bands — [Espressif C5 workshop](https://developer.espressif.com/workshops/esp-idf-with-esp32-c5/lecture-1/). The Wi-Fi overview says auto mode "does not mean simultaneous dual-band support" — [ESP-IDF Wi-Fi overview (C5)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c5/api-guides/wifi-driver/overview.html).
- On the C5, ESP-NOW and Long Range mode are listed as "only supported on 2.4 GHz band" — [ESP-IDF Wi-Fi overview (C5), IDF v6.1](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c5/api-guides/wifi-driver/overview.html).
  - Conflict: the ESP-NOW API page lists 5 GHz channels for the C5 ([ESP-NOW (C5)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html)). The feature-list bullet reads "ESP-NOW protocol and Long Range mode (only supported on 2.4 GHz band)", so the band restriction may apply to LR only. Test on hardware before relying on 5 GHz ESP-NOW.
- ESP-NOW v2.0 carries up to 1470 bytes and v1.0 carries 250. A v2.0 device receives both versions. A v1.0 device receives v2.0 packets only if they are 250 bytes or less. Limits: 20 peers, of which up to 17 can be encrypted (default 7). Broadcast needs the broadcast MAC added as a peer. Multicast encryption is not supported — [ESP-NOW docs](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html).
- ESP-NOW power saving: `esp_now_set_wake_window()` together with `esp_wifi_connectionless_module_set_wake_interval()` lets the radio sleep between wake windows. It works in station mode only, and the default keeps RX on all the time — [ESP-NOW docs](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html).
- `esp_now_set_peer_rate_config()` sets the PHY rate per peer, after `esp_wifi_start()` and `esp_now_add_peer()` — [ESP-NOW docs](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html).
- The ESP32-H2 has no Wi-Fi (BLE 5 + 802.15.4 only), so it cannot do ESP-NOW — [ESP32-H2 datasheet](https://documentation.espressif.com/esp32-h2_datasheet_en.pdf); [ESPHome ESP32 radio table](https://esphome.io/components/esp32/).

**Wi-Fi Long Range (LR) mode:**
- LR is "Espressif-patented". Its receive sensitivity is about 4 dB better than 802.11b and its theoretical distance is about 2-2.5x that of 11b. PHY rates are 1/2 and 1/4 Mbps ("very limited" throughput), and both ends must enable LR. LR is supported by "only ESP32-series chips (excluding the ESP32-C2)", which includes S3, C3, C6 and C5 — [ESP-IDF Wi-Fi overview (C6), IDF v6.1](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c6/api-guides/wifi-driver/overview.html).
- The C6 feature list names "ESP-NOW protocol and Long Range mode, which supports up to 1 km" — [ESP-IDF Wi-Fi overview (C6)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c6/api-guides/wifi-driver/overview.html). The C5 has LR on 2.4 GHz only — [ESP-IDF Wi-Fi overview (C5)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c5/api-guides/wifi-driver/overview.html).
- Forum users report enabling LR with `esp_wifi_set_protocol(..., WIFI_PROTOCOL_LR)` on the S3 under ESP-IDF — [esp32.com forum](https://esp32.com/viewtopic.php?p=144972). This is a user report, not documentation.

**Release status of the newer chips:**
- ESP32-C5 mass production was announced in May 2025, with initial support in ESP-IDF v5.5 — [Espressif developer blog](https://developer.espressif.com/blog/2025/05/news-esp32c5-mp/).
- The ESP-IDF docs are now at v6.1 (stable) — [ESP-IDF Wi-Fi overview (C6)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c6/api-guides/wifi-driver/overview.html).
- ESP32-H4 (BLE 5.4 + 802.15.4, aimed at battery devices) was announced on 27 March 2026 with samples on request. No mass-production notice was found — [Espressif press release](https://www.espressif.com/en/node/10417).
  - Specs conflict: CNX reports 320 KB SRAM and up to 4 MB PSRAM ([CNX Software](https://www.cnx-software.com/?p=128616)); Espressif's Chinese page reports 96 MHz and 384 KB SRAM.
- ESP32-S31 was announced on 26 March 2026: dual-core RISC-V at 320 MHz, 512 KB SRAM, Wi-Fi 6 on 2.4 GHz only, BT 5.4 LE + Classic, 802.15.4, Gigabit Ethernet MAC, 60 GPIOs in QFN80 8x8 mm. The datasheet is "Pre-release v0.2" — [Espressif news](https://www.espressif.com/en/node/10413); [S31 datasheet](https://documentation.espressif.com/esp32-s31_datasheet_en.pdf); [Circuit Cellar](https://circuitcellar.com/newsletter/espressif-unveils-esp32-s31-a-dual-core-risc-v-soc/).
- ESP32-P4 has no radio; a separate co-processor is needed via ESP-Hosted — [ESPHome ESP32 docs](https://esphome.io/components/esp32/).

**Chip prices and stock (snapshots, not live):**

| Chip | Price | Source |
|---|---|---|
| ESP32-S3FH4R2 (LCSC C3013940) | $3.99 @1 to $2.31 @1000+; 2,090 in stock | [LCSC](https://lcsc.com/product-detail/image/ESP32-S3FH4R2_C3013940.html) |
| ESP32-C6FH4 | $1.64 @5k (Future Electronics, 6-week lead time, 5k MOQ) | [Future Electronics](https://www.futureelectronics.com/p/esp32-c6fh4-C917616295) |
| ESP32-C6FH4 | $2.06 @1 (Digi-Key via Findchips, 324 in stock) | [Findchips](https://findchips.com/search/ESP32-C6-Zero) |
| ESP32-C5HF4 | €3.09 @1, ~2,949 in stock (Mouser.fr) | [Mouser.fr](https://www.mouser.fr/c/semiconductors/?q=ESP32) |
| ESP32-C5HF4 | $3.59, 2,899 stock (cached tracker, Aug 2026) | [mousersearch tracker](https://mousersearch.tscircuit.com/risc_v_processors/list) |
| ESP32-C5HF4 | Digi-Key lists it as "new product", 4-week lead time | [Digi-Key](https://www.digikey.com/en/products/detail/espressif-systems/ESP32-C5HF4/27566802) |

**Toolchain support:**

| Chip | Arduino-ESP32 (official docs) | PlatformIO | ESPHome |
|---|---|---|---|
| S3 | Yes (stable) | Official `espressif32` = Arduino 2.x only; Arduino 3.x via pioarduino | ESP-IDF default; Arduino available |
| C3 | Yes | same | ESP-IDF; Arduino available |
| C6 | Yes | Needs Arduino 3.x, so pioarduino | ESP-IDF only |
| C5 | Yes (stable; XIAO C5 needs core ≥ 3.3.5) | pioarduino | ESP-IDF only (`variant: esp32c5`) |
| C61 | Only as IDF component or with rebuilt static libs | pioarduino (with custom libs) | ESP-IDF only |
| H2 | Yes | pioarduino | ESP-IDF only ("officially" since 2025.6.0) |
| H4 / S31 / H21 | not listed | — | variants listed; "require ESP-IDF 6.1 or later" |
| P4 | Yes | pioarduino | ESP-IDF only, needs wireless co-processor |

Sources for the toolchain table:
- Arduino-ESP32 lists ESP32, C3, C5, C6, H2, P4, S2 and S3 as "Yes" for stable and development. C2 and C61 "require using Arduino as an ESP-IDF component or rebuilding the static libraries" — [Arduino-ESP32 docs](https://docs.espressif.com/projects/arduino-esp32/en/latest/getting_started.html).
- The latest 3.3.x component release seen is 3.3.12 — [Espressif component registry](https://components.espressif.com/components/espressif/arduino-esp32/versions/3.3.12/readme). The 3.3.0 readme did not yet list C5/C61 — [3.3.0 readme](https://components.espressif.com/components/espressif/arduino-esp32/versions/3.3.0/readme).
- The XIAO ESP32-C5 needs the esp32 board package 3.3.5 or higher — [Seeed wiki](https://wiki.seeedstudio.com/xiao_esp32c5_getting_started/). The XIAO C6 package needs esp32 > 3.0.0 — [Seeed wiki](https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/).
- PlatformIO's official `espressif32` platform still ships Arduino-ESP32 2.x (6.11.0 was reported as still on v2); pioarduino is the fork for 3.x — [PlatformIO forum](https://community.platformio.org/t/using-espressif-arduino-esp32-v3-2-0-with-platformio/47629). The newest pioarduino entry seen is 55.03.39, which maps to Arduino 3.3.9 / ESP-IDF 5.5.4 — [platform-espressif32 versions list](https://github.com/sivar2311/platform-espressif32-versions). These are community sources and are not dated 2026.
- ESPHome: the default framework is ESP-IDF for all variants. "Arduino framework is available for ESP32 (classic), ESP32-C3, ESP32-S2, and ESP32-S3"; C2, C5, C6, C61, H2 and P4 need ESP-IDF. The variant list includes esp32s31, esp32h4 and esp32h21 (IDF ≥ 6.1). The ESPHome "platformio toolchain is deprecated and will be removed in 2027.2.0" — [ESPHome ESP32 docs](https://esphome.io/components/esp32/).
- ESPHome 2025.6.0 made H2 "officially" supported, but said new variants were still being refined and were ESP-IDF only — [ESPHome 2025.6.0 changelog](https://esphome.io/changelog/2025.6.0/).
- ESPHome 2025.8.0 added an ESP-NOW component ("ESP-NOW mesh communication") and the nRF52 platform — [ESPHome 2025.8 blog](https://esphome.io/blog/2025/08/20/esphome-2025-8/).

### Inferences
- **Battery (radio part only).** The project's measured ~90 mA matches the S3 datasheet RX figure of 88 mA. With the radio listening 100% of the time:
  - C6 saves about 10 mA (11%).
  - C3 saves 4 mA.
  - C5 and C61 save nothing on 2.4 GHz.
  - C5 on 5 GHz costs about 22 mA extra.
  - No Wi-Fi-capable Espressif chip changes the battery picture much. The large lever is listening less, for example with ESP-NOW wake windows, which needs time-synchronised badges, or a different radio class (BLE/802.15.4 on H2 or Nordic).
- **Link budget at maximum TX on 11b 1 Mbps.**
  - S3: 21 + 98.4 = 119.4 dB
  - C3: 119.4 dB
  - C6: 120.2 dB
  - C61: 120.5 dB
  - C5 (2.4 GHz): 20 + 100.5 = 120.5 dB
  - So a new chip gains only about 1 dB. LR mode adds about 4 dB on any of these chips.
  - 5 GHz on the C5 loses about 6.6 dB of free-space path loss (20·log10(5.2/2.44)) plus about 4.4 dB sensitivity (-94 vs -98.4 dBm) and 3 dB TX power. It is clearly worse for range. Its only advantage would be a cleaner band at a crowded camp, which is not verified.
- **Current TX power.** The badge sets `esp_wifi_set_max_tx_power(52)`. Per the ESP-IDF API's 0.25 dBm unit (well-known API convention, not re-fetched in this pass), this is about 13 dBm, 8 dB below the S3's 21 dBm maximum.
  - Raising it would increase free-space range by about 2.5x (10^(8/20)) on the existing hardware.
  - At 20 Hz with a sub-millisecond frame, TX duty is about 1-2%, which adds only a few mA average even at 340 mA peak.
  - This is the cheapest range gain available and needs no new chip.
- **Airtime caution.** A small ESP-NOW broadcast at 1 Mbps DSSS lasts roughly 0.6-0.7 ms on air. This is an estimate from 802.11 framing (about 192 µs preamble plus about 60 bytes); I did not verify it against the ESP-NOW frame-format doc in this pass.
  - 300 badges × 20 Hz × 0.65 ms ≈ 3.9 s of airtime per second if all are in range. Even 50 badges in mutual range would occupy about 65% of the channel.
  - Longer range (more TX power, LR at 1/4 Mbps with about 4x airtime) enlarges the collision domain.
  - Higher PHY rates via `esp_now_set_peer_rate_config()` shorten airtime but cost sensitivity: 11g 6 Mbps is -93.2 dBm on the S3 versus -98.4 dBm at 1 Mbps.
  - Chip choice matters less here than rate, TX power and packet-rate policy.
- **H2 as the low-power Espressif option.** BLE RX of 24 mA is about 3.7x lower than S3 Wi-Fi RX, with BLE coded at -106.5 dBm and +20 dBm TX. That is a link budget of about 126 dB at 125 kbps. Using it means replacing ESP-NOW with BLE extended advertising/scanning or raw 802.15.4, and H2 badges could not talk to existing S3 badges.
- **C61 for this project.** It is a poor fit: no RMT, so WS2812 must use SPI/I2S; no Arduino board-manager support without rebuilt libraries; and no current advantage over the S3.
- **H4 and S31.** Neither is a 2026 camp option. H4 is at sampling stage only, and S31 is a pre-release datasheet in a large QFN80 package.

### Gaps
- ESP32-C3 BLE RX current: the C3 datasheet pages extracted here had no BLE current table.
- LCSC prices for ESP32-C6FH4, C5HF4, C3FH4 and H2FH4S. LCSC pages were not retrievable in this pass apart from the S3FH4R2; only Mouser, Digi-Key and Future snapshots were found.
- No independent bench measurement of continuous ESP-NOW RX current on S3 vs C6 vs C5 was found. Qoitech's measurements cover sleep currents only.
- The default PHY rate of ESP-NOW broadcast (reported as 1 Mbps by Espressif staff in an esp32.com thread, paraphrased) could not be pinned to an official doc.
- Whether C5 ESP-NOW really works on 5 GHz: the docs conflict (see above).
- Whether ESP32-C61 supports LR mode: covered by the docs' "all ESP32-series except C2" rule, but not stated explicitly.
- ESP32-H4 final current figures: no datasheet electricals found.

---

## Q2. Non-Espressif alternatives with real Arduino/PlatformIO support (Nordic nRF52840 / nRF54L15, Silicon Labs, WCH, RP2040/RP2350 + CYW43439, Telink)

### Takeaway
Nordic chips draw about 15-25x less receive current than ESP32 Wi-Fi: about 3.4-6.4 mA versus 78-88 mA. They do not support ESP-NOW, top out at +8 dBm TX, and have a smaller link budget (nRF52840 about 111 dB at BLE 125 kbps coded, versus about 119-124 dB for ESP Wi-Fi at full power). The nRF52840 has mature Arduino cores (Adafruit; PlatformIO `nordicnrf52`) and ESPHome support since 2025.8 (Zephyr, still "in development"). The nRF54L15 is better silicon, but its XIAO board "does not support the Arduino" per Seeed, so it is Zephyr/nRF Connect SDK territory. Silicon Labs (EFR32MG24) has an official Arduino core. WCH CH58x/CH59x Arduino support is fragmentary. No sourced data was gathered for RP2040/RP2350 + CYW43439 or Telink in this pass.

### Cited Findings

**Datasheet comparison:**

| Parameter | nRF52840 | nRF54L15 |
|---|---|---|
| CPU | Cortex-M4F 64 MHz (not re-verified in this pass) | 128 MHz Cortex-M33 + 128 MHz RISC-V coprocessor ([Nordic product page](https://www.nordicsemi.com/Products/nRF54L15)) |
| RAM / NVM | 256 KB / 1 MB (not re-verified) | 256 KB / 1.5 MB ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| Radios | BLE 5 incl. 125 kbps long range, 802.15.4 ([PS v1.8](https://infocenter.nordicsemi.com/pdf/nRF52840_PS_v1.8.pdf)) | BLE incl. Channel Sounding, LE Long Range 125/500 kbps ([RADIO doc](https://docs.nordicsemi.com/r/bundle/ps_nrf54l15/page/radio.html)), 802.15.4, proprietary 1/2/4 Mbps ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| RX current | 4.6 mA peak ([PS v1.8](https://infocenter.nordicsemi.com/pdf/nRF52840_PS_v1.8.pdf)); 6.4 mA @1 Mbps, 3 V DC/DC ([product brief](https://mouser.com/pdfdocs/Nordic_nRF52840_PB.pdf)) | 3.4 mA @3 V ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| TX current @0 dBm | 4.8 mA peak ([PS v1.8](https://infocenter.nordicsemi.com/pdf/nRF52840_PS_v1.8.pdf)) | 4.8 mA @3 V ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| Max TX | +8 dBm (-20 ... +8 dBm in 4 dB steps) ([PS v1.8](https://infocenter.nordicsemi.com/pdf/nRF52840_PS_v1.8.pdf)) | +8 dBm CSP, +7 dBm QFN ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| Sensitivity BLE 1M | -95 dBm (PS); PB says -96 dBm ([PB](https://mouser.com/pdfdocs/Nordic_nRF52840_PB.pdf)) | -96 dBm ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| Sensitivity 125 kbps coded | -103 dBm ([PS v1.8](https://infocenter.nordicsemi.com/pdf/nRF52840_PS_v1.8.pdf)) | Not found in Nordic docs. A third-party BL54L15 module datasheet gives -102 dBm, with -94 dBm at 1M ([RS module DS](https://docs.rs-online.com/a829/A700000013397894.pdf)) |
| Sensitivity 802.15.4 | — | -101 dBm ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| Sleep | — | 0.7-2.9 µA sleep modes @3 V ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |
| Status | PS v1.8 dated 2023-12-01 | CSP47/QFN52/QFN48 in mass production; QFN40 early sampling ([Nordic](https://www.nordicsemi.com/Products/nRF54L15)) |

- CNX describes the nRF54L15's RX current as half that of the nRF52840 — [CNX Software](https://www.cnx-software.com/2023/10/16/nordic-nrf54l15-cortex-m33-wireless-mcu-halves-rx-power-consumption-over-nrf52-chips/).

**Toolchain support:**
- **PlatformIO `nordicnrf52`:** supports three Arduino cores: Adafruit, sandeepmistry nRF5, and Arduino's archived mbed core. The cores are not API-compatible with each other — [PlatformIO forum](https://community.platformio.org/t/is-there-a-functional-difference-between-platformios-framework-arduinoadafruitnrf52-firmware-and-arduinos-official-firmware/17274/4); [PlatformIO board doc (Adafruit BSP)](https://docs.platformio.org/en/latest/boards/nordicnrf52/nrf52840_dk_adafruit.html). Current version and 2026 release status were not found.
- **ESPHome nRF52:**
  - Arrived in 2025.8.0 as a Zephyr-based platform — [ESPHome 2025.8 blog](https://esphome.io/blog/2025/08/20/esphome-2025-8/).
  - Boards: adafruit_feather_nrf52840, adafruit_itsybitsy_nrf52840, xiao_ble. Bootloaders: MCUboot (needed for OTA, BLE transport by default, needs an SWD programmer to flash) or the Adafruit bootloader (USB flashing). The docs say "support for all aspects of ESPHome on the NRF52 is still in development" — [ESPHome nRF52](https://esphome.io/components/nrf52/); [ESPHome nRF52 OTA](https://esphome.io/components/ota/zephyr_mcumgr/).
  - Zigbee on nRF52 was added in 2026.1 (initial sensor, binary sensor and switch) — summary of the [ESPHome nRF52 docs](https://esphome.io/components/nrf52/) via search; changelog page not opened.
- **nRF54L15 / XIAO nRF54L15:** Seeed's wiki (quoted by Hubtronics) says it "does not support the Arduino". Pakronics lists Arduino but notes "Arduino IDE is not currently supported". Zephyr / nRF Connect SDK and PlatformIO (Zephyr) are supported — [Hubtronics](https://hubtronics.in/seeed-studio-xiao-nrf54l15?tag=XIAO); [Pakronics](https://www.pakronics.com.au/products/seeed-studio-xiao-nrf54l15-ss101991421).
- **Silicon Labs:**
  - The official Arduino core supports Arduino Nano Matter, SparkFun Thing Plus Matter (MGM240P), and xG24/xG27/BGM220 kits, with BLE via ArduinoBLE or the SiLabs BGAPI stack. It needs Arduino IDE 2.x and a bootloader burn on first use — [SiliconLabs/arduino](https://github.com/siliconLabs/arduino).
  - The XIAO MG24 (EFR32MG24, 78 MHz M33, 4 MB flash, battery charging) is listed in a fork of the core; the official list was unclear — [Core Electronics XIAO MG24](https://core-electronics.com.au/seeed-studio-xiao-mg24-silicon-labs-efr32mg24-iot-development-board.html.plain.md); [Mindstyler fork](https://github.com/Mindstyler/siliconlabs-arduino).
  - No PlatformIO information was found.
- **WCH CH58x/CH59x:**
  - The community PlatformIO platform has CH58x/CH59x BLE examples, but its Arduino framework list names only CH32V parts — [pio-ch32v docs](https://pio-ch32v.readthedocs.io/en/latest/examples.html).
  - WeAct's WCH-BLE-Core covers CH573F/CH582F/CH592F/CH584F (programmed via WCHISPTool) — [WeActStudio](https://github.com/WeActStudio/WeActStudio.WCH-BLE-Core).
  - The request for a CH582 Arduino core is an old open issue — [openwch issue #69](https://github.com/openwch/arduino_core_ch32/issues/69).

### Inferences
- **Battery.** A Nordic badge that listens with BLE scanning at 100% duty would draw about 4-7 mA for the radio, versus about 90 mA today. The 64 WS2812 LEDs (35-270 mA per project context) would then dominate completely. Battery life becomes an LED question.
- **Range.** nRF52840 at +8 dBm with -103 dBm coded gives about 111 dB link budget, versus about 111 dB for the current S3 setting (13 dBm, -98.4 dBm) and 119 dB for the S3 at full power. A Nordic badge would roughly match today's range. With a PA/FEM such as the nRF21540 (not researched here) it could exceed it.
- **Cost of a move.** It means a full radio-protocol rewrite (BLE extended advertising + scanning instead of ESP-NOW), loss of interoperability with existing S3 badges and the ESP32 base station/bridge, and a different LED driver (Adafruit NeoPixel on nRF52 rather than FastLED RMT; not verified here). It is a large step for a camp deadline.
- **Arduino maturity.** Only the nRF52840 (Adafruit core) and SiLabs MG24 (official core) are realistic Arduino-first non-Espressif options. nRF54L15 is Zephyr-first.

### Gaps
- nRF54L15 BLE 125 kbps coded sensitivity from Nordic's own datasheet: the radio electrical table was not retrievable.
- nRF52840 CPU/RAM were not re-verified in this pass (widely known as 64 MHz M4F, 256 KB RAM, 1 MB flash).
- nRF52840 / nRF54L15 chip prices at LCSC/JLC: not found.
- RP2040/RP2350 + CYW43439 (Pico W / Pico 2 W) currents and Arduino (earlephilhower core) status: not researched. These modules have no ESP-NOW.
- Telink TLSR: no evidence of real Arduino/PlatformIO support was looked for or found.
- WS2812 driving on nRF52 (PWM + EasyDMA / I2S): not sourced.

---

## Q3. Off-the-shelf battery-friendly boards for prototypes (LiPo charger, small, quiescent current, price, LEDs)

### Takeaway
For quick battery prototypes the Seeed XIAO family is the most practical. Each board has an on-board LiPo charger, measures about 21 x 17.8 mm, costs about €5-8, and has measured deep-sleep currents of 13-17 µA for S3 and C6 (C3 about 42 µA). The XIAO ESP32-C6 has a switchable ceramic/u.FL antenna. The XIAO ESP32-C5 has u.FL with an included antenna, 8 MB flash and 8 MB PSRAM. DFRobot Beetle ESP32-C6 (about €5-6) and Adafruit ESP32-C6 Feather (about $15, with MAX17048 fuel gauge) are alternatives. None of these has an LED matrix, so each needs an external 8x8 WS2812 panel. Deep-sleep figures are irrelevant for an always-listening badge: the radio's 78-88 mA dominates. Board quiescent current (LDO, charger, LEDs) matters only in an "off" or sleep mode.

### Cited Findings

| Board | SoC | LiPo charger | Deep-sleep current | Antenna | LEDs | Price (snapshot) | Sources |
|---|---|---|---|---|---|---|---|
| Waveshare ESP32-S3-Matrix (SKU 27119), current badge | ESP32-S3FH4R2, 4 MB flash, 2 MB PSRAM | none (per project context: the battery version is being self-designed) | — | — | 8x8 WS2812 + QMI8658C IMU | $8.99 @1 (Waveshare); €14.06 (Voelkner); 2024: $15.99 Amazon / ~$10.26 AliExpress | [Waveshare](https://www.waveshare.com/esp32-s3-matrix.htm); [Voelkner](https://www.voelkner.de/products/12319243/Waveshare-ESP32-S3-Matrix-Entwicklungsboard-Wi-Fi-Bluetooth-5-LE-88-Matrix-512KB-SRAM-USB-C.html); [CNX 2024](https://www.cnx-software.com/2024/05/13/esp32-s3-matrix-board-features-64-leds-20-gpio-pins-9-axis-attitude-sensor-for-robotics-and-motion-control-applications/) |
| Seeed XIAO ESP32-S3 | ESP32-S3 | yes | 14 µA vendor; 13.4 µA measured (Qoitech). One user measured 298 µA when fed via 3V3 and 63 µA via 5V | not verified in this pass | none | £7.30 (Pi Hut, older snapshot) | [Fab Academy summary](https://fabacademy.org/2024/labs/kannai/Instruction/tips/battery/); [Qoitech](https://www.qoitech.com/?p=19961); [Seeed forum](https://forum.seeedstudio.com/t/xiao-esp32s3-deep-sleep-current-higher-than-expected/276916); [Pi Hut](https://thepihut.com/collections/seeed?page=1) |
| Seeed XIAO ESP32-C3 | ESP32-C3 | yes | 44 µA vendor; 41.6 µA measured | not verified in this pass | none | £4.80 ex VAT (Pi Hut); €5.07 (Mouser); $6.39 (TME) | [Seeed wiki](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/); [Qoitech](https://www.qoitech.com/?p=19961); [TME](https://www.tme.eu/lt/en/katalog/p,seeed-studio_1325/); [Mouser](https://www.mouser.fi/en/c/embedded-solutions/engineering-tools/rf-wireless-development-tools/multiprotocol-development-tools/?q=1063) |
| Seeed XIAO ESP32-C6 | ESP32-C6, 4 MB flash | yes (battery pads by D8/D5, red charge LED) | 15 µA vendor (3.8 V); 16.9 µA measured; modem-sleep 30 mA, light-sleep 3.1 mA vendor | ceramic on board + u.FL via RF switch (GPIO3 low enables, GPIO14 high selects external) | none | £5.20 ex VAT (Pi Hut); €5.71 (Mouser, 7-week lead) | [Seeed wiki](https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/); [Qoitech](https://www.qoitech.com/?p=19961); [Pi Hut](https://thepihut.com/collections/seeed?page=1) |
| Seeed XIAO ESP32-C5 | ESP32-C5, 8 MB flash + 8 MB PSRAM, 21 x 17.8 mm | yes (SGM40567); battery ADC on GPIO6 with enable on GPIO26 | 15 µA on battery, 375 µA on USB (vendor, "low power firmware") | u.FL with external antenna included | none | A$10.27 ex GST (25+: A$9.59; 50+: A$8.99); ¥1,290; first run limited to 5 pcs per person at one dealer | [Seeed wiki](https://wiki.seeedstudio.com/xiao_esp32c5_getting_started/); [Core Electronics](https://core-electronics.com.au/seeed-studio-xiao-esp32-c5.html.plain.md); [Openelab](https://openelab.com/products/seeed-studio-xiao-esp32-c5); [Switch Science](https://www.switch-science.com/products/10978); [Pakronics](https://www.pakronics.com.au/products/seeed-studio-xiao-esp32-c5-ss100010048) |
| Seeed XIAO nRF52840 / Plus | nRF52840 | yes (BQ25101 on Plus) | 5 µA vendor | — | none | $12.22 (Robotshop US); Plus $11.19 / £9.70 | [Robotshop](https://www.robotshop.com/products/seeedstudio-seeed-studio-xiao-nrf52840); [Core Electronics Plus](https://core-electronics.com.au/seeed-studio-xiao-nrf52840-plus.html.plain.md) |
| Seeed XIAO nRF54L15 | nRF54L15 | yes | "final board-level power data being verified" | — | none | £9.60-11.90 (Pi Hut) | [Pi Hut](https://thepihut.com/products/seeed-studio-xiao-nrf54l15); [Pakronics](https://www.pakronics.com.au/products/seeed-studio-xiao-nrf54l15-ss101991421) |
| Seeed XIAO MG24 | EFR32MG24 | yes | — | — | none | — | [Core Electronics](https://core-electronics.com.au/seeed-studio-xiao-mg24-silicon-labs-efr32mg24-iot-development-board.html.plain.md) |
| Adafruit ESP32-C6 Feather (5933) | ESP32-C6 | yes + MAX17048 fuel gauge; second LDO turns off I2C/NeoPixel | "as low as 17 µA" vendor | — | 1 NeoPixel | $14.95 (1-9), $11.96 (100+) | [Adafruit](https://www.adafruit.com/product/5933) |
| DFRobot Beetle ESP32-C6 (DFR1117) | ESP32-C6 | yes, 0.5 A, battery voltage detection | 14 µA (v1.0), 37 µA (v1.1) vendor; one user measured 0.67 mA, blamed on charge LED blinking | — | none | £4.70-4.80 (Pi Hut); €6.00 (Voelkner); €4.18 ex VAT (Farnell) | [DFRobot wiki](https://wiki.dfrobot.com/dfr1117/); [DFRobot forum](https://www.dfrobot.com/forum/topic/399338); [Pi Hut](https://thepihut.com/products/beetle-esp32-c6-mini-development-board) |
| Unexpected Maker TinyC6 | ESP32-C6 | yes, 700 mA LDO | "ultra low" (vendor, no figure) | onboard-antenna variant sold | — | $17 (Lectronz, $16 at 4+) | [Lectronz](https://www.lectronz.com/products/tinyc6); [Core Electronics](https://core-electronics.com.au/tinyc6-onboard-antenna-iot-projects.html) |
| Unexpected Maker TinyS3 / TinyS3[D] | ESP32-S3 | yes (JST PH), 700 mA LDO | "ultra low" (vendor, no figure) | onboard; [D] variant separate | — | $20 (Crowd Supply); TinyS3[D] $34.95 (Jameco) | [Crowd Supply](https://crowdsupply.com/unexpected-maker/tinys3); [Jameco](https://www.jameco.com/z/6401-Adafruit-Industries-TinyS3-D-ESP32-S3-by-Unexpected-Maker_2884959.html) |
| M5Stack NanoC6 | ESP32-C6FH4 | not stated | — | — | — | ¥1,320-1,342 | [Switch Science](https://www.switch-science.com/collections/lp-m5stack-atom) |
| M5Stack AtomS3R / AtomS3 Lite | ESP32-S3 (S3R adds 8 MB PSRAM) | not stated | — | — | — | ¥3,531 / ¥1,793 | [Switch Science](https://www.switch-science.com/collections/lp-m5stack-atom) |

Notes on the table:
- The board's regulator, charger and USB bridge explain why board deep-sleep figures exceed chip figures — [Qoitech](https://www.qoitech.com/?p=19961).
- One user cut a XIAO C3 to about 11 µA by removing the regulator and charger ICs — [Seeed forum](https://forum.seeedstudio.com/t/xiao-esp32s3-deep-sleep-current-higher-than-expected/276916).
- The ESP32-C6 has no native USB, only USB Serial/JTAG — [Adafruit](https://www.adafruit.com/product/5933).

### Inferences
- **Best fit for a quick battery prototype.** A XIAO ESP32-C6 (about €5-6) plus a stock 8x8 WS2812 panel plus a small LiPo. It has the lowest Wi-Fi RX of the ESP family, a built-in charger, and a switchable u.FL option for range tests. It is also inexpensive enough to build 10-20 test units.
- **For the custom 30 x 34 mm board.** The XIAO C6 schematic (ceramic antenna plus RF switch to u.FL) is a useful reference for a dual-antenna option.
- **XIAO C5.** Interesting for 2.4 vs 5 GHz experiments. It gives no current advantage on 2.4 GHz (87 mA RX), and supply appeared limited at launch.

### Gaps
- No data gathered this pass for: LilyGO T-Display-S3 / T-Dongle-S3, Heltec boards, Adafruit QT Py ESP32-S3 (believed to lack an on-board charger; not verified), Adafruit Feather ESP32-S3, FireBeetle 2 ESP32-C6, Waveshare ESP32-C6-Zero / S3-Zero, Waveshare round boards.
- Antenna type of XIAO ESP32-S3/C3 not verified (believed u.FL external).
- Seeed's own USD list prices were not retrievable; retailer prices above vary by VAT and region.
- No independent measurement of these boards in the "radio always on" state was found.

---

## Q4. Off-the-shelf LED-matrix boards with a battery that could replace the Waveshare board directly

### Takeaway
No off-the-shelf board was found that combines a small 8x8 (or similar) WS2812 matrix, an integrated LiPo with charger, and a badge-sized ESP32. M5Stack's Atom Matrix (5x5 WS2812C, classic ESP32-PICO-D4) has no battery. The Waveshare ESP32-S3-Matrix has no charger. The Ulanzi TC001 pixel clock (ESP32, 8x32 matrix, 4400 mAh, Arduino-flashable over USB) is the only battery-plus-matrix product found, and at desk-clock size it is not a badge. The custom battery board remains justified.

### Cited Findings
- **M5Stack Atom Matrix (C008-B):**
  - ESP32-PICO-D4 (dual LX6 240 MHz, 520 KB SRAM, 4 MB flash), 5x5 = 25 WS2812C-2020 LEDs, MPU6886 IMU, 2.4 GHz "3D antenna", 24 x 24 x 13.8 mm, 5 V USB-C input. No battery or charger is mentioned — [M5Stack docs](https://docs.m5stack.com/en/core/ATOM%20Matrix).
  - M5Stack warns that "excessive brightness or full-on operation can generate high temperatures" and recommends FastLED brightness 20 — [M5Stack docs](https://docs.m5stack.com/en/core/ATOM%20Matrix).
  - Price ¥3,113 (Switch Science) — [Switch Science](https://www.switch-science.com/collections/lp-m5stack-atom).
- **Ulanzi TC001:**
  - ESP32-WROOM-32D, 8x32 = 256 RGB LEDs, 3.7 V 4400 mAh battery, runtime "up to 5 hours" — [Elektor](https://www.elektor.com/products/ulanzi-tc001-esp32-based-smart-pixel-clock).
  - Matrix on GPIO32, battery ADC on GPIO34, CH340 USB-serial; Arduino-ESP32 examples available — [rroels hardware repo](https://github.com/rroels/ulanzi_tc001_hardware).
  - Can be flashed over USB-C without soldering — [blakadder review](https://blakadder.com/ulanzi-pixel-clock/).
- **flow3r (CCC Camp 2023 badge, precedent):** ESP32-S3 with 8 MiB RAM and 16 MiB flash, 40 RGB LEDs, round 240x240 display, optional battery compatible with the MCH2022 badge battery, open hardware — [CCC events blog](https://events.ccc.de/en/2023/06/05/camp23-the-flow3r-badge/).
- **Waveshare ESP32-S3-Matrix:** 8x8 RGB matrix, QMI8658C IMU, ESP32-S3FH4R2 — [CNX 2024](https://www.cnx-software.com/2024/05/13/esp32-s3-matrix-board-features-64-leds-20-gpio-pins-9-axis-attitude-sensor-for-robotics-and-motion-control-applications/); [Waveshare](https://www.waveshare.com/esp32-s3-matrix.htm).
- No Waveshare ESP32-C6 matrix board was found; only C6 LCD and mini boards came up in the search — [Waveshare search results](https://www.waveshare.com/esp32-s3-matrix.htm).

### Inferences
- **Closest off-the-shelf stopgap.** A Waveshare S3-Matrix plus an external LiPo charger/booster or a USB power bank. Alternatively, an Atom Matrix plus an M5 battery base; whether such a base exists for Atom was not verified here.
- **Ulanzi TC001 battery life.** 4400 mAh lasting about 5 h implies about 0.9 A average draw, roughly 3.5 mA per LED at default brightness. This underlines that LED current dominates any battery badge.

### Gaps
- M5Stack Atom battery accessories (for example "Atomic Battery Base") and their capacities: not researched.
- LilyGO boards with LED matrices: none found or researched.
- AliExpress-only 8x8 battery badges: not researched.

---

## Q5. Antenna: chip vs PCB vs u.FL and the effect on range

### Takeaway
No controlled, published range study comparing chip, PCB and u.FL antennas on ESP32 boards was found. The evidence is anecdotal and says layout and ground-plane clearance matter more than antenna type: about 10-20 dB between boards in one 2026 hobby test. A u.FL antenna helps only if the RF path is actually switched to it and the cable/antenna are decent. For a badge worn on the body, orientation and body shadowing (not researched here) likely dominate.

### Cited Findings
- **2026 hobby test of three boards against the same access point.**
  - The DevKitC V4 with the antenna folded up off the module was "consistently 10-20dB stronger" than an ESP8266 NodeMCU and a generic ESP32 board with a flush antenna.
  - None of the three had u.FL. Method: RSSI to one AP, with sample count and distance not stated.
  - Source: [dabase.com, 7 Sep 2026](https://dabase.com/blog/2026/esp-with-the-strongest-wifi-signal/).
- **Module PCB antennas.** An Espressif forum engineer said the module PCB antenna "actually is pretty decent", connected straight to the LNA. External antennas add connector and line losses — [esp32.com forum](https://esp32.com/viewtopic.php?p=49517); summary of results in [esp32.com threads](https://esp32.com/viewtopic.php?p=152676).
  - A user report: an on-PCB-antenna ESP-WROOM-02 connected better than its u.FL twin — [esp32.com](https://esp32.com/viewtopic.php?p=49517).
  - On an S3 u.FL board, adding an external antenna lowered RSSI by at least 3 dB compared with a DevKitC PCB antenna (-45 vs -52 dBm) — [esp32.com](https://esp32.com/viewtopic.php?p=152676).
- **u.FL routing.** Some boards route RF to the PCB antenna by default, and need a jumper or resistor move before a u.FL antenna works — [Elektroda](https://www.elektroda.com/news/news4124039.html).
- **XIAO ESP32-C6.** The antenna switch defaults to the ceramic antenna (GPIO14 low). GPIO3 must be driven low to enable the RF switch control — [Seeed wiki](https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/).
- **Multi-antenna support on the C5.** The ESP-IDF PHY guide supports external antenna switching via `esp_phy_set_ant_gpio()` and `esp_phy_set_ant()`, up to 16 antennas with at most 2 active, and advises against `ESP_PHY_ANT_MODE_AUTO` — [ESP-IDF PHY (C5)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c5/api-guides/phy.html).

### Inferences
- **For the custom 30 x 34 mm board.** Antenna keep-out and ground-plane clearance are likely worth more dB than choosing between S3, C6 or C5 (about 1 dB from Q1). The same holds for raising TX power from 13 to 21 dBm (+8 dB).
- **For prototypes.** Test with the same board in ceramic mode and in u.FL mode (XIAO C6) to quantify on-body loss at the camp.

### Gaps
- No quantified chip-antenna vs PCB-antenna gain figures for the Waveshare S3-Matrix or the XIAO boards.
- No data on body-worn badge antenna loss at 2.4 GHz was gathered.

---

## Q6. Cost and gain of moving from ESP32-S3 to ESP32-C6 or ESP32-C5 (firmware, FastLED/RMT on RISC-V, mixed-swarm ESP-NOW)

### Takeaway
Porting the current sketch to C6 or C5 is cheap. ESP-NOW and `esp_wifi` APIs are the same in Arduino-ESP32 3.x, the sketch has no core pinning, and the project already uses arduino-cli with the official core, which supports C5 and C6. The FQBN changes; the C5 should be locked to 2.4 GHz. FastLED supports both chips through RMT5, SPI and PARLIO drivers. The C6 RMT has no DMA, so watch for Wi-Fi-induced flicker. A mixed S3/C6/C5 swarm interoperates on the same 2.4 GHz channel. The gain is small: about 10 mA less RX on C6 and about 1 dB of link budget. The real wins (range +8 dB, battery from LEDs and duty-cycling) are available on the S3 today.

### Cited Findings
- **Arduino core support.** Arduino-ESP32 lists C5 and C6 as supported (stable) alongside S3 — [Arduino-ESP32 docs](https://docs.espressif.com/projects/arduino-esp32/en/latest/getting_started.html).
- **ESP-NOW interop.**
  - Channels must match (channel 0 means the current channel). v2.0 and v1.0 devices interoperate for packets of 250 bytes or less — [ESP-NOW docs](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html).
  - ESP-NOW "doesn't depend on Wi-Fi or Bluetooth" features, so the C6's extra radios do not change ESP-NOW behaviour — [esp32.com forum](https://esp32.com/viewtopic.php?p=121638).
- **C5 band default.** The C5 defaults to `WIFI_BAND_MODE_AUTO` and can be forced to one band with `esp_wifi_set_band_mode()` — [Espressif C5 workshop](https://developer.espressif.com/workshops/esp-idf-with-esp32-c5/lecture-1/).
- **FastLED (latest listed 3.10.4):**
  - Build badges cover ESP32, S2, S3, C2, C3, C5, C6, H2 and P4. C61 is absent.
  - The SPI driver covers "All ESP32 variants"; PARLIO covers "ESP32-P4, C5, C6, H2".
  - RMT5 is selected automatically on ESP-IDF 5+. "Using RMT4 is strongly recommended if you experience flickering with Wi-Fi enabled."
  - The build badges prove "compile coverage only".
  - Source: [FastLED GitHub README](https://github.com/FastLED/FastLED).
- **FastLED 3.9.3 (Nov 2024).** "ESP32C6 is now supported with the RMT5 driver without a #define hack". Because the C6 lacks RMT DMA it uses the non-DMA path, and the RMT buffer for non-DMA boards was doubled to reduce Wi-Fi corruption — [FastLED 3.9.3 beta notes (Reddit mirror)](https://nyc1.lr.ggtyler.dev/r/FastLED/comments/1gqv1mo/fastled_393_beta_release_3_for_400).
- **RMT channel counts.** S3 has 4 TX + 4 RX, C6 has 4 channels in total, C5 has 2 TX + 2 RX, and C61 has none — datasheets: [S3](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf), [C6](https://documentation.espressif.com/esp32-c6_datasheet_en.pdf), [C5](https://documentation.espressif.com/esp32-c5_datasheet_en.pdf), [C61](https://documentation.espressif.com/esp32-c61_datasheet_en.pdf).
- **CPU.** S3 is dual-core Xtensa at 240 MHz. C6 is single-core RISC-V at 160 MHz plus a 20 MHz LP core. C5 is single-core RISC-V at 240 MHz plus a 48 MHz LP core — datasheets as above.
- **USB.** The C6 has USB Serial/JTAG only, no native USB OTG — [Adafruit ESP32-C6 Feather](https://www.adafruit.com/product/5933).
- **ESPHome.** If the base station or tooling ever moves to ESPHome, C5/C6 there are ESP-IDF only and Arduino-framework code would not carry over — [ESPHome ESP32 docs](https://esphome.io/components/esp32/).

### Inferences
- **Firmware delta for C6/C5:**
  1. Change the FQBN to `esp32:esp32:esp32c6` or `esp32c5`.
  2. Change `LED_PIN` (14 is Waveshare-specific).
  3. On the C5, add `esp_wifi_set_band_mode(WIFI_BAND_MODE_2G_ONLY)` before setting channel 13 so it stays reachable by S3 badges.
  4. Keep `esp_wifi_set_protocol(11B|11G|11N)`. 11ax is irrelevant for ESP-NOW broadcast, and the S3 cannot receive HE frames.
  5. Drop the S3-specific `CDCOnBoot` option.
  6. Re-test FastLED timing under 20 Hz ESP-NOW traffic, since the C6 uses non-DMA RMT. Fall back to the SPI or PARLIO FastLED driver if flicker appears.
- **Mixed swarm.** S3 + C6 + C5 badges on channel 13 at 2.4 GHz with ESP-NOW packets under 250 bytes should interoperate. The C5's 5 GHz capability cannot be used in a mixed swarm.
- **Gain summary vs S3:**

| Option | Battery (RX) | Range (link budget) | Other gains | Other costs |
|---|---|---|---|---|
| C6 | ~-10 mA (~11%) | +0.8 dB | cheaper chip (~$1.6-2.1 vs ~$2.3-4 for S3FH4R2); 802.15.4 available | — |
| C5 | ±0 on 2.4 GHz | +1.1 dB on 2.4 GHz (2.1 dB better sensitivity, 1 dB less TX power) | 5 GHz option (C5-only swarms) | higher chip price (~€3.1) |

- **Higher-value levers on the existing S3:**
  - TX 13 → 21 dBm: +8 dB, about 2.5x free-space range.
  - LR mode: +4 dB, at about 4x airtime cost.
  - Lower LED brightness or LED power gating: LEDs are 35-270 mA versus a 10 mA radio delta.
  - ESP-NOW wake-window duty cycling with synchronised badges: potentially more than 50% radio savings, but it needs a time-sync design and was not tested here.
- **Recommendation.** Staying on S3 for the custom board is defensible. If a re-spin is planned anyway, the ESP32-C6 (C6FH4, QFN32 5x5 mm, in-package flash) is the low-risk upgrade: it is pin-light, cheaper, slightly lower power, fully supported in Arduino-ESP32 and FastLED, and ESP-NOW compatible with existing S3 badges. C5 makes sense only if 5 GHz experiments matter. H2 or Nordic make sense only if a protocol rewrite away from ESP-NOW is acceptable.

### Gaps
- No hands-on report found of FastLED flicker rates on C6/C5 with continuous ESP-NOW traffic.
- Whether ESP-NOW broadcast from a C6/C5 (11ax-capable PHY) is sent at exactly the same default rate and preamble as from an S3: not documented in the sources read. Expected to be 11b 1 Mbps for both, but unverified.
- Real-world ESP-NOW wake-window behaviour with hundreds of broadcasting nodes: not found.
- WS2812 idle current (which may explain the project's 35 mA floor) is not sourced here and should be measured.
