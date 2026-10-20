# Wi-Fi-radio swarm and mesh options on Espressif chips (ESP-NOW, ESP-WIFI-MESH, ESP-Mesh-Lite, painlessMesh): scaling, range, battery

Researched 2026-10-17. Baseline: Herz-Schwarm badges (ESP32-S3) each broadcast a 17-byte ESP-NOW packet at 20 Hz on channel 13, unencrypted, with the radio always on (~90 mA). Target: a few hundred badges outdoors on a site several hundred metres across. Each source is dated where the date matters. Calculations marked "inference" are my own arithmetic from the cited parameters.

---

## 1. ESP-NOW limits (2026), airtime, and channel capacity for hundreds of 20 Hz broadcasters

### Takeaway
ESP-NOW broadcast has no protocol limit on how many devices can send or receive. The real limit is airtime. At the default 1 Mbps, one 17-byte packet holds the channel for about 0.72 ms, so 20 Hz from every badge fills a whole 2.4 GHz channel at roughly 70 badges. Even at 30% load, the most a CSMA channel without ACKs can carry cleanly, only about 20 badges fit. A few hundred badges need two or more of these together: transmit at about 1-2 Hz, use 6 Mbps OFDM (about 5x less airtime for about 5 dB less sensitivity), and suppress or slot transmissions against the shared beat.

### Cited Findings
**Peers and payload**
- Unicast peer table: at most 20 peers in total (`ESP_NOW_MAX_TOTAL_PEER_NUM`). At most 17 of them can be encrypted (`ESP_NOW_MAX_ENCRYPT_PEER_NUM`), default 7, set with `CONFIG_ESP_WIFI_ESPNOW_MAX_ENCRYPT_NUM`. Broadcast and multicast frames cannot be encrypted. A broadcast peer (FF:FF:FF:FF:FF:FF) must be added before broadcasting. — [ESP-IDF ESP-NOW API (latest, ESP32-S3)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/network/esp_now.html)
- Before ESP-IDF v5.1 the encrypted-peer limit was fixed at 6. From v5.1 the default is 7 and the maximum 17 (ESP32-C2: default 2, max 4). Broadcast "has no theoretical device limit", but interference grows with device count. Espressif's `esp-now` component control model uses broadcast, so the 20-peer cap does not apply to it. — [Espressif ESP-FAQ: ESP-NOW](https://docs.espressif.com/projects/espressif-esp-faq/en/latest/application-solution/esp-now.html)
- Espressif staff on esp32.com (Jul 2024), answering a question about 1,000+ ESP32-S3 boards: encrypted and direct links are "fairly limited", but a broadcast to FF:FF:FF:FF:FF:FF reaches "all ESPs in range ... independent of how many that are". — [esp32.com thread](https://esp32.com/viewtopic.php?p=134934)
- Payload: v1.0 allows 250 bytes (`ESP_NOW_MAX_DATA_LEN`) and v2.0 allows 1470 bytes (`ESP_NOW_MAX_DATA_LEN_V2`). A v2 device receives from both v1 and v2 devices. A v1 device receives only v1 frames; it accepts v2 frames up to 250 bytes and truncates or drops longer ones, depending on IDF version. — [ESP-IDF ESP-NOW API](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/network/esp_now.html)
- ESP-NOW v2 has been available since ESP-IDF v5.4. — [MicroPython ESP-NOW doc (Infineon fork mirror)](https://ifx-micropython-psoc-edge.readthedocs.io/en/latest/_sources/library/espnow.rst.txt); the 1470-byte limit is also in the [ESP-IDF v5.4.2 ESP-NOW docs](https://docs.espressif.com/projects/esp-idf/en/v5.4.2/esp32c5/api-reference/network/esp_now.html)

**Frame size, PHY rate, and airtime**
- Frame format (from the API docs): 24-byte MAC header, category code (1), OUI (3), random value (4), vendor element header (7: element ID, length, OUI, type, version), payload, and 4-byte FCS. An ESP-NOW frame therefore carries about 43 bytes of overhead plus the payload. The docs also state: "The default ESP-NOW bit rate is 1 Mbps." — [ESP-IDF ESP-NOW API](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/network/esp_now.html)
- Rate setting: `esp_now_set_peer_rate_config()` sets the TX rate per peer and supports all rates, including Wi-Fi 6 HE rates. Call it after `esp_wifi_start()`, `esp_now_init()` and `esp_now_add_peer()`. The legacy `esp_wifi_config_espnow_rate()` is deprecated in v5.2-v5.x and removed in v6.0. — [ESP-FAQ](https://docs.espressif.com/projects/espressif-esp-faq/en/latest/application-solution/esp-now.html)
- 802.11b DSSS timing: the long preamble plus PLCP header lasts 192 µs, sent at 1 Mbps; the short preamble lasts 96 µs, with the header at 2 Mbps. 1 and 2 Mbps legacy operation requires the long preamble. — [Keysight 89600 WLAN DSSS timing help](https://helpfiles.keysight.com/csg/89600B/Webhelp/Subsystems/wlan-dsss/content/trc_time.htm); 802.11b slot time is 20 µs — [arXiv 1102.3607](https://arxiv.org/pdf/1102.3607)

**Measured throughput and loss**
- Measured ESP-NOW throughput at 1 Mbps, ESP32-DevKitC one-to-one: about 214 kbps in an open environment and about 555 kbps in a shielding box. — [ESP-FAQ](https://docs.espressif.com/projects/espressif-esp-faq/en/latest/application-solution/esp-now.html)
- Atomic14 desk test (broadcast, PCB antennas): about 320 packets/s (about 0.6 Mbit/s) in standard mode against about 95 packets/s (about 0.2 Mbit/s) in LR mode. — [atomic14 ESP-NOW range video notes](https://atomic14.com/videos/posts/oz0a7Ur7nko)
- Forum report (not a controlled test): 13 ESP32-C3 boards broadcasting about 130 messages/s in total on one channel saw roughly 20% loss. Espressif staff blamed channel congestion and suggested splitting devices across channels. — [esp32.com "Limit for receiving concurrent esp_now messages?"](https://esp32.com/viewtopic.php?p=146575) (seen via search summary only)
- Espressif's `esp-now` component (not raw ESP-NOW) repeats each frame `retransmit_count` times (default **10**, max 31, from `ESPNOW_FRAME_CONFIG_DEFAULT`). The header warns "Too many packet retransmissions will lead to network congestion." — [espressif/esp-now espnow.h](https://raw.githubusercontent.com/espressif/esp-now/master/src/espnow/include/espnow.h)
- ESPHome docs: every ESP-NOW device on the channel receives and partly processes every broadcast, which "wakes the radio and CPU on those devices". Broadcasts are not acknowledged. — [ESPHome ESP-NOW component](https://esphome.io/components/espnow/)

### Inferences
- **Airtime per 17-byte badge packet:** MPDU = 43 + 17 = 60 bytes = 480 bits.
  - 1 Mbps DSSS: 192 µs + 480 µs = **672 µs** on air, about **722 µs** including DIFS (50 µs). Random backoff comes on top, but contending nodes share it.
  - 2 Mbps: about 432 µs.
  - 11 Mbps CCK, short preamble: about 140 µs.
  - 6 Mbps ERP-OFDM: about 110 µs (20 µs preamble + 21 × 4 µs symbols + 6 µs signal extension), about 140-160 µs with DIFS. The OFDM timing is standard 802.11a/g and was not fetched this session.
  - LR at 250 kbps: at least 1.9 ms for the payload bits alone. The LR preamble length is undocumented.
- **Channel load:** Current setup: 12 badges × 20 Hz × 0.72 ms = about 17% of channel airtime, which is fine. At 300 badges × 20 Hz the offered load is about 430% of a channel, so the channel collapses. Badges supported at a 30% load target:

  | PHY rate | 20 Hz | 5 Hz | 2 Hz | 1 Hz |
  |---|---|---|---|---|
  | 1 Mbps | ~21 | ~83 | ~210 | ~415 |
  | 6 Mbps OFDM | ~95 | ~375 | ~940 | — |
  | LR 250 kbps | ~7 | ~28 | ~70 | ~140 |

- **Why 30%:** broadcasts have no ACK or retry, so every collision is a lost sample. With hidden terminals (badges far apart on a large site that cannot hear each other but reach a common receiver), behaviour approaches unslotted ALOHA, where a frame survives with probability e^(-2G). At G = 0.3, about 55% of frames survive; at G = 0.1, about 82%. Treat 10-30% as the planning range, not 70-80%.
- **Sensitivity cost:** 6 Mbps OFDM cuts airtime about 5x and costs 5.2 dB of sensitivity (-93.2 vs -98.4 dBm on the S3, see section 6). For a dense crowd where most neighbours are within tens of metres, that trade looks worthwhile. Keep 1 Mbps or LR for the few base-to-badge "effect" packets that must reach the edge.
- **Rate reduction and scheduling ideas:**
  - (a) Lower each badge's beacon rate to 1-2 Hz. A heartbeat phase counter does not need 20 Hz: each packet can carry the phase plus a timestamp, and receivers extrapolate between packets. RSSI proximity can be averaged over a few packets per second.
  - (b) Trickle-style suppression (RFC 6206 idea, not researched here): a badge that has already heard k or more neighbours advertising the same beat or effect state skips its own transmission. In dense clusters, airtime then grows sub-linearly with badge count.
  - (c) Beat-locked slotting: superframe = one beat (or a fixed 200-500 ms), with each badge transmitting in a slot chosen by MAC hash. Random hashing into S slots collides a lot. 300 badges into 800 slots gives about 1 - e^(-300/800) ≈ 31% of badges sharing a slot with someone in range, so slots need listen-before-claim re-selection (STDMA, as in AIS). TDMA also concentrates traffic into windows, which matters if listen windows are used for power saving (section 3).
  - (d) Multiple channels: put base and effect traffic on one channel and badge beacons on another, or split the swarm in two. Espressif staff suggested this too, but it forces a channel-hopping receiver design.
- **Payload size is not the bottleneck.** At 1 Mbps the fixed cost is about 536 µs (192 µs preamble plus 43 bytes), against 8 µs per payload byte. Packing more state into fewer packets, such as the neighbour list or effect parameters, is nearly free; sending more packets is expensive. ESP-NOW v2's 1470 bytes is only useful for bulk transfers (OTA, config); a 1470-byte frame at 1 Mbps holds the channel for about 12 ms.
- If the team adopts Espressif's `esp-now` component, `retransmit_count` must be cut from 10 to 1-2 for beat frames, or it multiplies airtime 10x.

### Gaps
- No published controlled measurement of ESP-NOW broadcast loss against node count (50-500 nodes) was found. All large-N evidence is anecdotal.
- The exact CSMA parameters Espressif uses for ESP-NOW broadcast are not documented: CWmin, CCA threshold, and whether a 9 µs short slot applies at OFDM rates.
- The LR preamble/PLCP duration is not published, so LR airtime is only a lower bound.
- The ESP-NOW RX path limit (Wi-Fi RX buffers, receive-callback rate) on the S3 is unknown. The forum's 20% loss at only about 130 msg/s (about 9% airtime) hints that receiver-side processing may limit things before airtime does.

---

## 2. ESP-NOW Long Range mode (WIFI_PROTOCOL_LR): range gain, interoperability, chip support, airtime cost

### Takeaway
LR is an Espressif-proprietary PHY with raw rates of 1/2 and 1/4 Mbps (500 and 250 kbps). Only ESP chips can decode it: all ESP32 series except the C2, so S3, C3, C6 and C5. It gains roughly 4 dB of sensitivity, and field tests show about 1.5-3x the range of standard ESP-NOW: about 450 m near-lossless open field and about 500 m walk-test reach. Each packet holds the channel at least 3-4x longer than at 1 Mbps, so LR suits a few long links (base station to far badges, or relay nodes), not 20 Hz traffic from hundreds of badges.

### Cited Findings
- LR claims from the ESP-IDF v5.3 Wi-Fi guide (ESP32-S3):
  - "Long Range (LR) mode is an Espressif-patented Wi-Fi mode which can achieve a one-kilometer line of sight range."
  - Raw PHY rates are 1/2 Mbps and 1/4 Mbps.
  - Reception sensitivity is about 4 dB better than 802.11b, giving a theoretical 2-2.5x the 11b distance.
  - CCA and backoff follow the 802.11 specification.
  - — [ESP-IDF v5.3 Wi-Fi guide, LR section](https://docs.espressif.com/projects/esp-idf/en/v5.3/esp32s3/api-guides/wifi.html)
- LR compatibility rules (same guide):
  - "Only ESP32 chip series devices (except ESP32-C2) can transmit and receive the LR data."
  - An LR-enabled ESP32-S3 SoftAP is incompatible with ordinary 802.11 stations, because its beacons go out in LR.
  - An LR-enabled station that is not LR-only stays compatible with ordinary networks.
  - Recommended only when both ends are Espressif devices and throughput needs are very small.
  - — [ESP-IDF v5.3 Wi-Fi guide](https://docs.espressif.com/projects/esp-idf/en/v5.3/esp32s3/api-guides/wifi.html)
- Espressif developer blog (20 Dec 2024), ESP32-C6-DevKitM-1, PCB antenna, TX power not stated:

  | Mode | Open field | Forest |
  |---|---|---|
  | ESP-NOW | ~100% to 150 m, ~60% at 300 m | <50% at 125 m |
  | ESP-NOW-LR | ~100% to 450 m, ~40% at 900 m | <50% at 400 m |
  | Plain Wi-Fi | ~60% at 150 m | — |

  LR throughput was about 100 kbps at 150 m and about 10 kbps at 900 m. Latency stayed under 25 ms up to 900 m. — [Espressif: ESP-NOW for outdoor applications](https://developer.espressif.com/blog/esp-now-for-outdoor-applications/)
- Atomic14 walk test (TinyPico base on a balcony, TTGO in a backpack, PCB antennas, broadcast at 64 packets/s, some trees and fences):
  - Standard mode: last packets at about 320 m, often 30% loss beyond 50-100 m.
  - LR on both ends: packets up to about 500 m.
  - Desk-test throughput dropped to about a third in LR (95 against 320 packets/s).
  - — [atomic14](https://atomic14.com/videos/posts/oz0a7Ur7nko)
- Setup reported on esp32.com: `esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_LR)`, then `esp_wifi_config_espnow_rate(WIFI_IF_STA, WIFI_PHY_RATE_LORA_250K)` before `esp_now_init()`. — [esp32.com "How to maximize ESP-NOW range?"](https://esp32.com/viewtopic.php?p=130053)
- On an ESP32-C3, a user with 11B|11G|11N|LR enabled got "invalid rate, need change phy mode to LR" when selecting the LORA_250K or 500K rates. — [esp32.com thread (Chinese)](https://esp32.com/viewtopic.php?p=116681) (search summary only; staff answer not captured)
- Arduino: `WIFI_PROTOCOL_LR` should be applied after `WiFi.mode(...)`, on both AP and STA interfaces if both are used. — same esp32.com threads, per search summary
- The ESP-IDF "latest" (v6.x) ESP-NOW and PHY pages fetched this session do not mention LR at all. The LR text lives in the v5.3 Wi-Fi guide and in rate enums. — [ESP-IDF latest ESP-NOW](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/network/esp_now.html), [ESP-IDF latest PHY guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/phy.html)

### Inferences
- **Interoperability:** every badge that must hear an LR frame needs LR in its protocol bitmap. Ordinary 802.11 receivers, including Wi-Fi sniffers and non-ESP gear, cannot decode LR. Whether one S3 radio set to 11B|11G|11N|LR receives both 1 Mbps and LR ESP-NOW frames without reconfiguring is not documented. The C3 forum error suggests LR transmit rates may need an LR-only bitmap. **Test this on the bench** before designing a mixed scheme, for example badges beaconing at 1 Mbps or 6 Mbps among themselves while the base sends effects in LR.
- **Range gain:** Espressif's own "+4 dB gives 2-2.5x" is optimistic. 4 dB is 1.58x in free space and 1.26x beyond the two-ray breakpoint (40 dB/decade). The measured 3x (150 to 450 m) in the Dec-2024 blog probably mixes in the default standard ESP-NOW rate and environment effects. Plan for **about 1.5-2x** range from LR on body-worn badges.
- **Base station strategy:** today badges reach the base at only -85 to -95 dBm against -98.4 dBm 1 Mbps sensitivity, a 3-13 dB margin. Better than LR on the badges:
  - Put LR (and an external high-gain antenna) only on the base and on a handful of fixed relay posts.
  - Have relays re-broadcast effects at a normal rate.
  - Raise base TX EIRP up to the 20 dBm EU limit and mount it high.
- **Airtime:** a 60-byte LR-250k frame is at least 1.9 ms against 0.67 ms at 1 Mbps. At 1 Hz LR beacons, 300 badges would use about 60% of the channel, so LR beacons from every badge are not viable at that scale.

### Gaps
- No measured LR sensitivity figure in dBm for the S3 or C6 was found in a datasheet. Only the "+4 dB over 11b" claim exists.
- No measurement of LR behaviour in a dense multi-node network was found (collisions, CCA interaction with 11b/g/n traffic).
- Whether ESP32-C5 supports LR on 5 GHz is undocumented. Presumably LR is 2.4 GHz only, but this is unverified.
- An esp32.com user claimed 650 m line-of-sight ESP32-S3 range without LR, and that LR "can only be enabled on ESP-IDF". The thread could not be pinned down, so the claim is unverified. The API is callable from Arduino-ESP32 regardless.

---

## 3. ESP-NOW power saving: wake window and interval, modem and light sleep, measured currents, beat-synchronised listening

### Takeaway
ESP-IDF (v5.0+) can duty-cycle the radio for ESP-NOW with a wake **window** inside a repeating **interval**: `esp_now_set_wake_window()` with `esp_wifi_connectionless_module_set_wake_interval()`. TX works at any time. Measured on an ESP32-S3 (FeatherS3, MicroPython on IDF 5.0.2), board current falls from about 103 mA (radio always on) to 50 mA at 10% duty and 45 mA at 2% duty. That cuts the radio's roughly 60 mA share almost to zero. The remaining floor is CPU and board, about 44 mA in that test, against 13-22 mA (S3 modem-sleep at 40-80 MHz, idle) or 0.24 mA (light sleep) in the datasheet. Windows must be synchronised at the application layer. No documented API sets the window phase when disconnected, so a beat-locked window needs a bench check.

### Cited Findings
**API and behaviour**
- `esp_now_set_wake_window(window)` sets how long the radio stays awake, in ms (0-65535). The default is the maximum, meaning RX is always on. Sleep is supported only when the chip is a **station**. — [ESP-IDF ESP-NOW API](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/network/esp_now.html)
- Connectionless modules (ESP-NOW, DPP, FTM) can sleep while connected or disconnected:
  - TX works during sleep with no extra configuration.
  - For RX, RF, PHY and baseband turn on for *Window* ms at the start of each *Interval*. Each module has its own Window, and power save uses the largest.
  - The event `WIFI_EVENT_CONNECTIONLESS_MODULE_WAKE_INTERVAL_START` fires at each interval start, and Espressif recommends transmitting in it.
  - When connected to an AP, interval starts align with the AP's TBTT, so senders and receivers associated with the same AP share windows.
  - Disconnected-state sleep needs `CONFIG_ESP_WIFI_STA_DISCONNECTED_PM_ENABLE`, which is on by default.
  - — [ESP-IDF Wi-Fi performance and power save](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/wifi-driver/wifi-performance-and-power-save.html)
- Espressif FAQ:
  - IDF ≥ v5.0 uses `esp_now_set_wake_window()` plus `esp_wifi_connectionless_module_set_wake_interval()`; earlier versions used `esp_wifi_set_connectionless_wake_interval()`.
  - "Sender and receiver windows must be synchronized at the application layer."
  - Data sent outside the window is missed.
  - Set `CONFIG_ESP_WIFI_STA_DISCONNECTED_PM_ENABLE=y`.
  - — [ESP-FAQ](https://docs.espressif.com/projects/espressif-esp-faq/en/latest/application-solution/esp-now.html)
- Modem sleep (`WIFI_PS_MIN_MODEM` / `MAX_MODEM`) applies only to a station associated with an AP, waking at DTIM or the listen interval. `WIFI_PS_NONE`, the equivalent of `WiFi.setSleep(false)`, keeps RF on for the lowest latency at the highest power. — [ESP-IDF power save](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/wifi-driver/wifi-performance-and-power-save.html)

**Measured currents**
- glenn20, MicroPython on ESP-IDF v5.0.2, Nordic PPK2, `pm=(window_ms, interval_ms)` (circa 2023):

  | Board | Radio always on | 38% duty (75/200) | 25% (75/300) | 10% (50/500) | 2% (10/500) | Radio off |
  |---|---|---|---|---|---|---|
  | ESP32-S3 (FeatherS3) | 103 mA | 67 mA | 57 mA | 50 mA | 45 mA | 43.8 mA |
  | ESP32 (Beetle) | 100 mA | 56 mA | — | 36 mA | 31 mA | 28.9 mA |

  The interval should be a multiple of 100 ms, and messages arriving while the radio is off are lost. — [glenn20/upy-esp32-experiments ESPNowPowerManagement](https://github.com/glenn20/upy-esp32-experiments/tree/main/ESPNowPowerManagement)
- ESP32-S3 datasheet v2.2 (3.3 V, 25 °C):
  - RX (802.11b/g/n HT20): **88 mA**, with peripherals disabled and CPU idle.
  - TX peak: **340 mA** at 802.11b 1 Mbps @21 dBm; 291 mA at 11g 54 Mbps @19 dBm.
  - Modem-sleep (Wi-Fi clock-gated), dual core in WAITI: 13.2 mA at 40 MHz, 22.0 mA at 80 MHz, 27.6 mA at 160 MHz, 32.9 mA at 240 MHz. That is with all peripheral clocks off; 18.8 / 36.1 / 42.3 / 47.6 mA with them on.
  - Light-sleep: **240 µA**, plus 140 µA for 8 MB octal PSRAM. Deep-sleep: 7-8 µA.
  - — [ESP32-S3 datasheet v2.2](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf)
- The Espressif `esp-now` component lists low-power support only as an unchecked TODO item. — [esp-now User Guide](https://github.com/espressif/esp-now/blob/master/User_Guide.md)

### Inferences
- **Where the 90 mA goes:** the badge's floor matches the datasheet's 88 mA RX figure. The radio's receive chain is the load, not transmission. TX at 20 Hz × 0.67 ms × 340 mA averages only about 4.6 mA at 21 dBm, and less at lower TX power.
- **Beat-synchronised listening:** use a superframe of one or two beats (e.g. 500-1000 ms) with a 10-50 ms shared listen window (1-10% duty). Radio cost falls from about 60 mA to about 1-6 mA. Pair it with dropping the CPU to 80 MHz and using automatic light sleep between LED frame updates (WS2812s latch, so the MCU need only wake to push new frames). The MCU floor could then drop from about 44 mA to roughly 10-25 mA before LEDs.
- **Battery life:** for a 1000 mAh LiPo, excluding LED current, that is about 11 h at 90 mA against about 30-60 h at 15-30 mA.
- **Conflict with capacity:** if everyone transmits only inside a short shared window, the whole swarm's traffic lands in that window. 300 badges × 0.72 ms is about 216 ms of airtime at 1 Mbps, which cannot fit in a 50 ms window. Even at 6 Mbps (about 0.15 ms per packet) it needs about 45 ms. Windowed listening at hundreds of badges therefore needs:
  - (a) only a rotating subset (e.g. 10-20%) of badges transmitting per window,
  - (b) a higher PHY rate, and/or
  - (c) a longer window with slot assignment.
- **Window phase:** the connectionless interval when disconnected is internally timed. Its start is reported (`WAKE_INTERVAL_START`), but no API to phase-shift it was found. Two ways to make the window follow the beat, both need bench testing:
  - Change `esp_now_set_wake_window()` dynamically, or toggle between max window and a small one, at beat-locked times from a hardware timer.
  - Have each badge resynchronise its beat phase to its own interval start, so the swarm converges to a common phase. This works only if interval timing is stable relative to the crystal (±10 ppm class).
- **Station mode required:** badges must run in STA mode (not AP or AP+STA) for ESP-NOW sleep to work.

### Gaps
- No measurement of ESP-NOW wake-window power on the S3 under Arduino-ESP32 3.x / IDF 5.4-5.5 was found. glenn20's numbers are MicroPython on IDF 5.0.2, with the CPU not in light sleep.
- No documentation was found on combining the ESP-NOW wake window with automatic light sleep (`esp_pm_configure` with `light_sleep_enable`), or on whether Arduino-ESP32's prebuilt libraries have `CONFIG_PM_ENABLE` / tickless idle enabled.
- No published latency or energy cost was found for re-enabling RX (window start) or for `esp_wifi_start()`/`stop()` cycling.
- WS2812 quiescent current per LED (64 LEDs) was not researched here, but it may set a floor comparable to the MCU's.

---

## 4. Multi-hop options: Espressif `esp-now` component, ESP-WIFI-MESH, ESP-Mesh-Lite, painlessMesh, other ESP-NOW flooding libraries

### Takeaway
For a broadcast-heavy, latency-sensitive, mobile swarm, only ESP-NOW-based flooding fits. Espressif's `esp-now` component (TTL- and RSSI-gated forwarding with dedup) and small libraries like zh_network qualify, and only for rare base-originated traffic (effects, wave start), never for the 20 Hz beat. ESP-WIFI-MESH and ESP-Mesh-Lite build router-rooted IP trees: always-on SoftAP+STA nodes, 10-30 ms (8-12 ms Mesh-Lite) per hop, and 5-60 s healing. painlessMesh is TCP/JSON over SoftAP+STA with a default of 4 connections per node and explicit warnings against frequent broadcasts. None of the three suits hundreds of moving badges.

### Cited Findings
**Espressif `esp-now` component** (IDF component; IDF ≥4.4, v2 payload on IDF ≥5.4)
- Frame header fields:
  - `broadcast`, `group`, `ack`
  - `retransmit_count` (5-bit, max 31, default 10)
  - `forward_ttl`: "Number of hops in data transfer", max 31 (`ESPNOW_FORWARD_MAX_COUNT` 0x1f)
  - `forward_rssi`: packets received below this RSSI are not forwarded, "to avoid network congestion caused by packet transfer"
  - `magic`: a per-packet ID, used to filter duplicates
  - `filter_adjacent_channel` ("Because ESP-NOW is sent through HT20, it can receive packets from adjacent channels")
  - `filter_weak_signal`
  - `security` (application-layer encryption)
  - — [espnow.h](https://raw.githubusercontent.com/espressif/esp-now/master/src/espnow/include/espnow.h)
- Further header details: payload is `ESP_NOW_MAX_DATA_LEN_V2 - 20` on IDF ≥ 5.4, otherwise 230 bytes. `forward_enable` and `forward_switch_channel` init options exist. Default queue size is 32. — [espnow.h](https://raw.githubusercontent.com/espressif/esp-now/master/src/espnow/include/espnow.h)
- From the User Guide:
  - "Hundreds of devices can be controlled" through unicast, broadcast and group control.
  - Security: ECDH key exchange with a proof-of-possession string, AES128-CCM for data.
  - "16 devices can be configured in 5 seconds"; OTA: "50 devices can be upgraded in 3 minutes".
  - Recommended chips: ESP32, C2, C3, S2, S3, C6.
  - Low-power support is a TODO.
  - — [esp-now User Guide](https://github.com/espressif/esp-now/blob/master/User_Guide.md)
- Distribution: `idf.py add-dependency "espressif/esp-now=*"` (ESP-IDF component; no Arduino packaging stated). Apache-2.0. — [espressif/esp-now](https://github.com/espressif/esp-now)

**ESP-WIFI-MESH** (ESP-IDF built-in)
- Tree topology with exactly one root, which connects to a router and is the only gateway. The root is fixed by the user or elected by router RSSI (10 iterations, 90% vote).
- Per-hop latency 10-30 ms. Root failure heals in <10 s, child failure in <5 s, network build <60 s.
- Broadcast and multicast are supported.
- Espressif's performance test used 100 devices, 6 layers and 6 downstream connections.
- No power-save or Arduino support is described in the current guide.
- — [ESP-IDF ESP-WIFI-MESH guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/esp-wifi-mesh.html)

**ESP-Mesh-Lite** (`espressif/esp-mesh-lite`, release/v1.0)
- SoftAP+STA IP mesh on IoT-Bridge, in which every node can reach the external network at the IP layer.
- 1-15 layers and 1-10 downstream connections per node. Normally one root, connected to a router.
- Per-hop delay 8-12 ms. Root-loss repair <50 s, child-loss repair <45 s.
- 50-device performance test.
- Exposes an ESP-NOW wrapper for application use, with payload ≤249 bytes.
- Chips: ESP32, C2, C3, S2, S3, C6, C5, C61. ESP-IDF 5.x only.
- — [Mesh-Lite User Guide](https://github.com/espressif/esp-mesh-lite/blob/release/v1.0/components/mesh_lite/User_Guide.md); [repo](https://github.com/espressif/esp-mesh-lite) (101 open issues at time of fetch)

**painlessMesh** (Arduino and PlatformIO registry; GitLab primary, GitHub mirror)
- Default mode WIFI_AP_STA, TCP between nodes, JSON for all messages.
- "painlessMesh does not create a TCP/IP network of nodes."
- SNTP-like time sync; no accuracy figure is given.
- `init()` takes `maxconn`, default 4.
- Mesh size is limited "(we think) by the amount of memory in the heap".
- Warnings: `delay()` can make the mesh "fall apart"; "be conservative in the number of messages (and especially broadcast messages) you sent per minute"; delivery is not guaranteed.
- — [painlessMesh README (GitHub mirror)](https://github.com/gmag11/painlessMesh)
- Users report tcp_alloc assert crashes, fixed by changing the AsyncTCP version or the toolchain. — [painlessmesh-user group](https://groups.google.com/g/painlessmesh-user) (search summary)

**Other ESP-NOW mesh libraries**
- **zh_network** (aZholtikov):
  - ESP-NOW mesh with a per-node routing table "updated only as needed", broadcast and unicast, and delivery confirmation events.
  - Max payload 218 bytes. "The number of devices on the network and the area of use is not limited" (author's claim). No periodic messages and no pre-pairing.
  - All nodes must share a channel and `ZH_NETWORK_MAX_MESSAGE_SIZE`.
  - Tested on ESP-IDF v5.5 and ESP8266 RTOS SDK 3.4. Packaged as an Arduino/PlatformIO library, "tested on VSCode + PlatformIO. Not on Arduino IDE."
  - — [zh_network](https://github.com/aZholtikov/zh_network)
- **mesh_now** (nellowtcs, ESP Component Registry): auto peer discovery, multi-hop routing, message queuing, optional payload encryption, IDF ≥4.4. — [mesh_now 1.0.2 readme](https://components.espressif.com/components/nellowtcs/mesh_now/versions/1.0.2/readme) (search summary only)

### Inferences
- **Flooding cost:** every relay re-broadcast is another full airtime unit. Flooding one message to N badges costs up to N transmissions, and if every badge originates traffic, airtime grows as O(N²). Use `forward_ttl` = 2-3, a `forward_rssi` threshold (relay only weakly-heard packets, i.e. from far away), `magic` dedup and `retransmit_count` = 1-2. Flood only base/bridge-originated effect and wave packets (about 1 per few seconds).
- **Beat sync without a mesh:** keep it single-hop. Each badge corrects its phase from the neighbours it hears (pulse-coupled-oscillator, "firefly" style), and synchronisation spreads across the site without explicit relaying.
- **Why the IP meshes fail here:**
  - Topology: tree with one root and router dependency.
  - Healing: 5-60 s is far too slow for walking people.
  - Latency: 10-30 ms per hop exceeds the beat-sync budget at 5+ hops.
  - Power: SoftAP+STA keeps the radio always on (no ESP-NOW-style duty cycling), which removes the battery gains from section 3.
  - painlessMesh adds TCP connection churn and JSON overhead.
  - Their published tests (50-100 static nodes) are below the target scale.
- **The wave effect:** "wave start time" fits naturally as a TTL-limited flood with an absolute timestamp in the shared beat timebase. Each relay forwards the same start time, so hop latency does not skew the visual wave.

### Gaps
- No independent field reports of the `esp-now` component's forwarding at more than 50 nodes were found.
- No painlessMesh time-sync accuracy measurements or large-N (more than 50 nodes) stability reports were found.
- Older ESP-IDF docs reportedly stated ESP-WIFI-MESH maximum layer and capacity figures (e.g. 25 layers, 1000 nodes). The current guide states none, so these were not verified.
- zh_network and mesh_now have no published performance data. Maturity is unknown (single-author projects).

---

## 5. ESPHome ESP-NOW support (version, features, mesh, limits)

### Takeaway
ESPHome added an `espnow` component in **2025.8.0 (20 Aug 2025)**. As of docs version 2026.9.1 it offers send/broadcast actions, receive/broadcast/unknown-peer triggers, peer management, `max_payload_size` up to 1470 (v2), and a Packet Transport integration with its own encryption. There is no mesh or relaying (despite the release blog's "mesh" wording), no link-layer encryption, and no documented Long Range or wake-window power-save options. When Wi-Fi is used, the channel is locked to the AP channel. ESPHome is workable for a simple broadcaster or receiver badge, but beat sync, slotting and LR would need custom C++ components.

### Cited Findings
- ESPHome 2025.8.0 (released 20 Aug 2025) introduced `[espnow] Basic communication between ESP32 devices` (esphome#9582, by @nielsnl68). — [ESPHome 2025.8.0 changelog](https://esphome.io/changelog/2025.8.0/)
- The 2025.8 release blog headlines "ESP-NOW mesh communication" and lists "Mesh sensor networks" as a use case, but describes only direct device-to-device communication. No multi-hop relaying is described. — [ESPHome 2025.8 blog](https://esphome.io/blog/2025/08/20/esphome-2025-8/)
- Current component docs (ESPHome 2026.9.1):
  - Options: `channel` (cannot be set when Wi-Fi is used; ESP-NOW then follows the Wi-Fi channel), `auto_add_peer`, `enable_on_boot`, `peers`, `max_payload_size` (default 250; above 250 uses v2 frames up to 1470 bytes, which "only work with peers that also support them" and reserve more RAM).
  - Actions: `espnow.send`, `espnow.broadcast`, `espnow.peer.add/delete`, `espnow.set_channel` (1-14, no effect when Wi-Fi is enabled).
  - Triggers: `on_receive`, `on_broadcast`, `on_unknown_peer`.
  - No link-layer encryption; the ESP-NOW Packet Transport Platform provides encryption instead.
  - ESP32-H2 is not supported; ESP32-P4 works through `esp32_hosted`.
  - — [ESPHome ESP-NOW component](https://esphome.io/components/espnow/)
- The same docs say "channels 1-11 are allowed in the US and most of Europe". This conflicts with EU regulators, who allow channels 1-13 (see section 6). — [ESPHome ESP-NOW component](https://esphome.io/components/espnow/)
- 2025.11.0 added ESP-NOW transport via hosted co-processors. A `max_payload_size` (v2) option is attributed to 2026.7.0 by a secondary index. — [ESPHome 2025.11.0 changelog](https://esphome.io/changelog/2025.11.0/) (secondary attribution for 2026.7.0 not verified on the official changelog)

### Inferences
- ESPHome badges could join the swarm as listeners or effect injectors, for example a base or bridge built in ESPHome. They must speak the same raw packet format via `espnow.broadcast` with a lambda-built payload, and they would run at the default rate (1 Mbps) with the radio always on.
- To get beat-locked slots, PHY rate selection, LR, or wake windows, an ESPHome badge would need an external component (custom C++) calling `esp_now_set_peer_rate_config()`, `esp_wifi_set_protocol()` and `esp_now_set_wake_window()`. That is possible, but then little of ESPHome's value remains for the badge firmware itself.
- With ESPHome's Wi-Fi enabled (e.g. for OTA or a Home Assistant API), ESP-NOW must share the AP channel. At a camp, that means the camp network's channel rather than channel 13.

### Gaps
- The ESPHome docs state no peer count, RX queue, or throughput limits.
- No documentation was found on whether ESPHome's ESP32 builds enable `CONFIG_ESP_WIFI_STA_DISCONNECTED_PM_ENABLE` or expose any ESP-NOW power-save setting.

---

## 6. Interference and spectrum at a hacker camp: channel 13 in the EU, overlap with camp Wi-Fi, 5 GHz ESP-NOW on ESP32-C5

### Takeaway
Channel 13 (2472 MHz) is legal in the EU at up to 20 dBm EIRP under EN 300 328. ESP-NOW at 1 Mbps uses a roughly 22 MHz DSSS signal, so channel 13 still overlaps a camp AP on channel 11 by about 10 MHz. Espressif's own header notes that ESP-NOW frames are even received from adjacent channels. ESP-IDF documents 5 GHz peer channels (36-177) for ESP-NOW on the ESP32-C5, so 5 GHz ESP-NOW appears supported. It costs about 6.5 dB more free-space loss, has no 1 Mbps DSSS rate (6 Mbps OFDM is the floor), and comes with EU outdoor and DFS constraints that were not verified here.

### Cited Findings
- EU (via the Austrian regulator RTR): 2.4 GHz WLAN uses channels 1 (2.412 GHz) to 13 (2.472 GHz) on a 5 MHz raster. With 20 MHz channels, only 4 do not overlap: 1, 5, 9, 13. — [RTR 2400 MHz spectrum](https://www.rtr.at/TKP/was_wir_tun/telekommunikation/spectrum/bands/2400MHz/Spektrum2400MHz.en.html)
- EN 300 328 caps 2.4 GHz wideband transmitters at 20 dBm EIRP; V2.2.2 is the harmonised version. — [IB-Lenhardt EN 300 328 glossary](https://ib-lenhardt.com/kb/glossary/en-300-328)
- Espressif's `esp-now` component: "Because ESP-NOW is sent through HT20, it can receive packets from adjacent channels." It provides `filter_adjacent_channel` to drop them. — [espnow.h](https://raw.githubusercontent.com/espressif/esp-now/master/src/espnow/include/espnow.h)
- ESP-IDF country config sets the channel range with `schan`/`nchan` (e.g. 1 and 13). Under the AUTO policy, scanning is active on channels 1-11 and passive on 12-14. "Please consult local 2.4 GHz RF operating regulations." — [ESP-IDF v5.3 Wi-Fi guide](https://docs.espressif.com/projects/esp-idf/en/v5.3/esp32s3/api-guides/wifi.html)
- ESP-NOW peer channels: 1-14 on 2.4 GHz. The ESP32-C5 page also lists a 5 GHz range of channels 36 through 177 for paired devices. On C5, sleep is supported only in station mode. — [ESP-IDF ESP-NOW (ESP32-C5)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c5/api-reference/network/esp_now.html)
- ESP32-C5 is Espressif's first dual-band (2.4 + 5 GHz) Wi-Fi 6 SoC and is in mass production. Arduino support lagged at launch. — [Espressif ESP32-C5 news](https://espressif.com/en/news/ESP32-C5); [Hackaday](https://hackaday.com/tag/5ghz/)
- ESP-Mesh-Lite lists ESP32-C5 as supported. — [Mesh-Lite User Guide](https://github.com/espressif/esp-mesh-lite/blob/release/v1.0/components/mesh_lite/User_Guide.md)
- PlatformIO's official `platform-espressif32` does not support Arduino-ESP32 3.x or new chips such as C5/C6. The community fork **pioarduino** provides them; a version list shows platform 55.03.39 with Arduino 3.3.9 and IDF 5.5.4. — [CNX Software on pioarduino](https://cnx-software.com/2024/08/27/platform-espressif32-fork-platformio-arduino-esp32-c6-esp32-c5-esp32-h2-esp32-p4/); [PlatformIO forum](https://community.platformio.org/t/esp32-arduino-core-3-x-and-platformio-status/42008); [sivar2311 version list](https://github.com/sivar2311/platform-espressif32-versions)

### Inferences
- **Overlap with camp Wi-Fi:** camp APs on channels 1/6/11 put channel 11 (2451-2473 MHz DSSS, or 2452-2472 MHz OFDM) on top of channel 13's lower 10-12 MHz. The badges' CCA will defer to that energy (losing airtime) or collide with it (losing packets).
  - Channel 13 is still the best 2.4 GHz choice if the camp NOC sticks to 1/6/11.
  - If the NOC uses the EU 1/5/9/13 plan, channel 13 is occupied. Coordinate with the NOC, or check on site with a spectrum or Wi-Fi survey.
- **Setting the country explicitly:** set it in firmware, e.g. `esp_wifi_set_country()` with "DE" or "EU" and nchan = 13 (or `WiFi.setCountry` style wrappers), so channel 13 transmits at the legal power and future IDF defaults (some regions limit to 1-11) do not silently block it.
- **5 GHz trade-offs:**
  - Gains: far less congestion, plus more channels for splitting the swarm.
  - Costs: about 6.5 dB extra free-space loss (20·log(5.2/2.45)), more body absorption, and a 6 Mbps minimum rate (about 5 dB less sensitive than 1 Mbps on 2.4 GHz).
  - Net, roughly 10+ dB less link budget than 2.4 GHz at 1 Mbps. That is fine for dense badge-to-badge beat sync over tens of metres, poor for reaching a distant base.
  - All badges would need to be C5 (S3 is 2.4 GHz only), so it is a hardware respin.

### Gaps
- EU 5 GHz outdoor rules for ESP-NOW-like devices were not researched in this pass: which sub-bands allow outdoor use, and the DFS/TPC obligations in 5470-5725 MHz. An ESP-NOW node without radar detection may be barred from DFS channels. This needs a regulatory source.
- No source confirms whether ESP-NOW on C5 5 GHz is supported in Arduino-ESP32 3.3.x, or what PHY rates it uses there.
- No information was found on which 2.4 GHz channels the CCC camp NOC uses (past camps or 2027 plans).
- The default country code in current ESP-IDF and Arduino builds was not verified.

---

## 7. Range numbers: ESP32-S3 at 13-20 dBm, antennas, body blocking, LR gains

### Takeaway
On paper the S3 has a strong link budget: 21 dBm TX (20 dBm EIRP legal in the EU) and -98.4 dBm sensitivity at 1 Mbps, about 118 dB. Measured ESP-NOW with PCB antennas reaches about 150 m near-lossless and about 300 m maximum in open field, about 450-500 m with LR, and a third to half of that in forest or obstructed paths. Chest-worn badges add roughly 10-20 dB of body shadowing when the wearer's body is in the path, and crowds add about 10-15 dB more. Plan for reliable badge-to-badge links of tens of metres in a crowd and about 100-150 m in open line of sight. A several-hundred-metre site therefore needs a few fixed, elevated relay or base nodes, not a single base.

### Cited Findings
- ESP32-S3 datasheet v2.2:
  - RX sensitivity: 802.11b 1 Mbps **-98.4 dBm**, 2 Mbps -95.4, 5.5 Mbps -93.0, 11 Mbps -88.6; 802.11g 6 Mbps **-93.2**, 54 Mbps -76.5; 802.11n HT20 MCS0 -92.6, MCS7 -74.2 dBm.
  - TX power: 802.11b 21.0 dBm, 11g 6 Mbps 20.5 dBm, 54 Mbps 19.0 dBm.
  - — [ESP32-S3 datasheet v2.2](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf)
- Espressif test (ESP32-C6, PCB antenna, Dec 2024):
  - Open field: ESP-NOW about 100% to 150 m, about 60% at 300 m; LR about 100% to 450 m, about 40% at 900 m.
  - Forest: ESP-NOW <50% at 125 m; LR <50% at 400 m.
  - — [Espressif outdoor blog](https://developer.espressif.com/blog/esp-now-for-outdoor-applications/)
- Atomic14 (PCB antennas, trees and fences, broadcast):
  - 0-50 m: usually 100% delivery, but 40-60% loss in unlucky spots or behind a tree.
  - 50-100 m: about 30% loss is common.
  - Standard mode lost everything beyond about 320 m; LR reached about 500 m.
  - — [atomic14](https://atomic14.com/videos/posts/oz0a7Ur7nko)
- Espressif indoor reliability test (19 Dec 2024): 8 ESP32 nodes at 4 packets/s across a university building, with only about 50% of nodes judged reliable. Loss was dominated by walls and structure, and the recommendations were multiple central units and app-level delivery control. — [Espressif ESP-NOW reliability blog](https://developer.espressif.com/blog/reliability-esp-now/)
- Body shadowing at 2.4 GHz (Januszkiewicz, Sensors 2018):
  - FDTD: a body between dipoles raised path loss from about 44 to about 65 dB when the receiver was 0.3-0.4 m from the body, a "10-20 dB" near-body increase. The difference shrank to about 10 dB at 1 m and about 6 dB at 4 m.
  - Indoor measurement: 1 person in the path added about +10 dB, 2 people about +15 dB.
  - — [Januszkiewicz 2018, PMC6211019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6211019/)
- LR adds about 4 dB of sensitivity over 11b (Espressif). — [ESP-IDF v5.3 Wi-Fi guide](https://docs.espressif.com/projects/esp-idf/en/v5.3/esp32s3/api-guides/wifi.html)

### Inferences
- **Link budget (approximate):**
  - 20 dBm EIRP and -98.4 dBm sensitivity give about 118 dB.
  - Free-space loss at 2.45 GHz is 20·log10(d_m) + 40.2 dB: about 80 dB at 100 m, about 90 dB at 300 m.
  - Chest-height antennas (about 1.3 m) hit the two-ray breakpoint at about 4·h1·h2/λ ≈ 55 m, after which loss rises at about 40 dB/decade. That puts about 300 m at about 105 dB before body loss.
  - Add 10-20 dB for the wearer's body, 10-15 dB for crowd blocking, and about 5-10 dB for fading margin, and the link closes only to about 50-150 m in practice. That is consistent with the field tests above and with the team's -85 to -95 dBm at the base.
- **Effect of TX power:** each 3 dB of TX power is worth about 1.2x distance beyond the breakpoint. Going from 20 to 13 dBm (7 dB less) shortens range to roughly 0.67x but saves TX energy. TX is only about 5% of the budget (section 3), so lowering TX power is mainly useful for *reducing interference and collision footprint* in a dense crowd (better spatial reuse), not for battery.
- **Antenna placement:** keep the PCB antenna edge clear of the LiPo and the LED-matrix copper, and facing outward (away from the chest). Chip and PCB antennas typically give about 0-3 dBi. The base should use an external dipole or patch, elevated well above head height to clear crowd shadowing. That gain shows up symmetrically on badge-to-base links.
- **Proximity effect:** body orientation alone swings RSSI by 10-20 dB, so RSSI-based proximity among chest-worn badges will be noisy. Use median or EWMA over several packets per neighbour, which argues for keeping at least 2-5 Hz beacon rates locally (tension with section 1's capacity limit, so pair it with 6 Mbps OFDM).

### Gaps
- No ESP32-S3-specific outdoor ESP-NOW range measurement with stated TX power and antenna was found. Available field data is for C6 (Espressif) and ESP32/TinyPico (Atomic14).
- No measurements were found for chest-worn ESP32 badges specifically, nor for crowd-scale (hundreds of people) 2.4 GHz attenuation at festivals or camps.
- Antenna gain and efficiency figures for the badge's specific S3 module and PCB layout are unknown. They need a measurement, e.g. RSSI against distance with a fixed reference node.
