# Homelib follow-up: new sources and findings
Source: the device-mesh topic in the user's homelib library (62 items), four homelib research runs and the primary sources they cite; gathered 2026-10-17

Scope note. The four homelib research write-ups (Supercon 2025 badge, espressif/esp-now, MeshCore, WHY2025/39C3) are LLM-generated and mostly restate the bookmarked page plus generic design advice. The Supercon and ESP-NOW runs found no post-event or large-N data, and the ESP-NOW run's fetch of the coin-cell example returned a GitHub feature-flag page instead of the example. Every finding below was therefore re-checked against its primary source: repository code and commit history, official docs, or the original article. Anything not tied to a primary source is marked **unverified**. Two homelib sources contain errors. The simeononsecurity MeshCore-vs-Meshtastic guide has the licences reversed (section 3). The hackgyver WHY2025 guide calls the UI processor an "ESP32-C4", but it is an ESP32-P4 (section 1). Material already in the other notes files is not repeated unless it changes.

## 1. Deployed badge meshes: Supercon 2025, Hackaday Europe 2026, WHY2025, BornHack 2026, other events

### Takeaway
The Supercon 2025 Communicator mesh did not "repeat anything". The shipped firmware ran a bounded flood with a TTL of 3, a duplicate cache, suppression after hearing one other repeat, CAD before transmitting, and shedding of relayed packets when the queue was half full. It ran on 906.25 MHz, 500 kHz, SF7 at 9 dBm with the PA in its "low" setting, and it carried only human-typed chat. The organisers' only post-event statement is that it "worked flawlessly, even on microwatts", with no numbers attached. For Hackaday Europe 2026 the same badges moved to 869.525 MHz at 250 kHz, and the chat TTL went from 3 to 8.

WHY2025 handed out about 2,500 badges with an SX1262 that did not work as shipped: it needed two bodge wires, a hand-soldered antenna connector and a co-processor reflash. No source says how many badges ever joined a mesh.

BornHack 2026 shipped a MeshCore badge set to the stock EU/UK Narrow channel. A 2027 CCC camp should therefore expect attendee MeshCore nodes inside the 869.4–869.65 MHz sub-band. None of these events published delivery, latency, duplicate-rate or battery measurements.

### Cited findings
**Supercon 2025 Communicator badge, firmware as shipped (commit bc5d473b, 1 Nov 2025)**
- Radio: 906.250 MHz (frequency slot 9), 500 kHz bandwidth, SF7, CR 4/5, a 16-symbol preamble, sync word 0x12, and TX 9 dBm with `power_level = "low"`, commented "RF amp power, for power saving" — [lora.py @bc5d473b](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/bc5d473b/firmware/badge/net/lora.py). Default config: `radio_tx_power` 9, `chat_ttl` 3, `send_cooldown_ms` 1 — [badge.py @bc5d473b](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/bc5d473b/firmware/badge/hardware/badge.py)
- The README describes 500 kHz as legal in the US and says the badge uses Meshtastic SHORT_TURBO slot numbers. Slots that overlap Meshtastic defaults are blocked "so we can be good neighbors" — [firmware README](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/README.md)
- Frame layout: a 16-byte header (sync 0x07E9, CRC-16 checksum, a flags/TTL nibble, length, 4-byte destination, 4-byte source, port, sequence number), then the payload. The maximum frame is 250 bytes — [protocols.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/net/protocols.py)
- Forwarding:
  - Duplicates are keyed on the 16-bit checksum and kept in a "recently seen" table for 6,000 s.
  - A relay is queued only on first reception, and only if the 20-entry TX queue is less than half full.
  - At send time a relayed copy is dropped if the badge has heard it more than once.
  - Relayed packets (not the badge's own) are discarded while the queue is more than half full.
  - Transmissions are spaced at least 0.1 s apart.
  - — [net.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/net/net.py).
  - The README says badges skip a repeat "if they hear another badge within range repeat it first" — [firmware README](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/README.md)
- Channel access: an SX1262 CAD (`scanChannel`) loop runs before every transmission — [lora.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/bc5d473b/firmware/badge/net/lora.py)
- Addresses are 4 bytes taken from the chip ID. A code comment says that at Supercon's size a 2-byte address has a "~50% chance of address collision" — [net.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/net/net.py)
- Traffic types: TEXT_CHAT (port 6: 2 + 10 + 100 bytes of payload, so a 128-byte frame), SIGNED_TEXT_CHAT, PING/PONG and CONFIG_OVERRIDE. In my reading of the shipped apps, no app sends a periodic beacon — [chat.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/bc5d473b/firmware/badge/apps/chat.py); [net_tools.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/apps/net_tools.py)
- Signed broadcasts: organiser badges hold an RSA-1024 private key and sign with PSS/SHA-256. CONFIG_OVERRIDE (port 4: a 128-byte signature, a 20-byte key and an 80-byte value) is sent with TTL 15 and lets the key holder change any config value on every badge — [crypto.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/net/crypto.py); [config_manager.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/apps/config_manager.py); [generate_rsa_keys.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/bc5d473b/firmware/scripts/generate_rsa_keys.py)
- Known weaknesses listed in the README: DoS by spamming, spoofing other badges, and "Small RSA key size" — [firmware README](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/README.md)
- Changes after the event:
  - 29 Dec 2025: "Fix LoRa frame checksum calculation and validation" — [commit c60066c](https://github.com/Hack-a-Day/2025-Communicator_Badge/commit/c60066cefc371dc882861e439e67c6fc38c65202).
  - 14 Feb 2026, "for supercon europe": chat TTL default raised from 3 to 8 (fallback from 2 to 7) and the rock-paper-scissors TTL from 2 to 4 — [PR #57](https://github.com/Hack-a-Day/2025-Communicator_Badge/pull/57).
  - 13 May 2026: frequency 869.525 MHz, bandwidth 250 kHz, "Only one slot in EU" — [commit 5b0ee746](https://github.com/Hack-a-Day/2025-Communicator_Badge/commit/5b0ee746).
  - An open issue tracks merging the US and EU branches — [issue #63](https://github.com/Hack-a-Day/2025-Communicator_Badge/issues/63)
- Hardware failure: SMA antenna connectors snapped off "throughout and after" the event. An organiser replied that only one side had been pasted and soldered — [issue #53](https://github.com/Hack-a-Day/2025-Communicator_Badge/issues/53)
- Radio module: Seeed Wio-SX1262-N with an ESP32-S3-WROOM-1. Neither the BOM nor the docs give a battery capacity — [BOM](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/hardware/communicator_pcb/communicator_pcb_BOM.csv)
- Outcome claim from the organisers: "At Supercon, we ran our own custom mesh network, and it worked flawlessly, even on microwatts". The same post says the badge would be reused at Hackaday Europe (Lecco, 16–17 May 2026) "on different frequencies" — [Hackaday, 18 Feb 2026](https://hackaday.com/2026/02/18/2026-hackaday-europe-call-for-participation-we-want-you/). I found no other post-event report (searched Hackaday, the repo issues and general web).

**WHY2025 (Netherlands, Aug 2025)**
- About 2,500 badges: "roughly 2.5k are out there". The badge pairs an ESP32-C6 and an ESP32-P4 with an SX1262. The C6 is wired to the LoRa chip and the P4 to the screen and keyboard, and the P4's base firmware reflashes the C6 at every boot. The PR warns that LoRa firmware without an antenna "may fry the LoRa chip". MeshCore support was "mainly redefining pins", and the author reached about half of Hamburg's repeaters — [MeshCore PR #671, merged 27 Aug 2025](https://github.com/meshcore-dev/MeshCore/pull/671)
- WHY2025 wiki:
  - The linked radio datasheet is the Ai-Thinker RA-01SH: SX1262, 803–930 MHz, +22 dBm ([Ai-Thinker Ra-01SH](https://docs.ai-thinker.com/en/Ra-01SH)).
  - The datasheet pinout differs from the KiCad schematic.
  - Meshtastic needs the CAD and busy pins soldered to the C6 (two wires).
  - LoRa firmware overwrites ESP-Hosted, so the badge loses Wi-Fi and Bluetooth while it runs.
  - The stock antenna works "with a little tuning at 1.7 SWR @868".
  - — [wiki: Meshtastic on the WHY2025 badge](https://wiki.why2025.org/Project:Meshtastic_on_the_WHY2025_badge)
- The MeshCore UI by Peetz0r can only send and receive channel messages. It has no word wrap (about 30 characters are visible), no channel joining, no DMs, no adverts and no settings screen. Users must flash the C6 with the BLE companion build to configure the badge, then flash the UI build — [peetz0r.nl/badge](https://peetz0r.nl/badge). At 39C3 there was a flashing session with €6 antenna kits — [39C3 hub](https://events.ccc.de/congress/2025/hub/en/event/detail/meshcore-on-your-why2025-badge)
- The hackgyver Meshtastic guide (22 Sep 2025):
  - Bodge wires of about 4.5 and 4.8 cm in AWG 30.
  - LongFast with the default key `AQ==`.
  - A demo patch broadcasts every 3 min, with 20 s as the minimum because the UART queue is small.
  - — [hackgyver.fr](https://hackgyver.fr/pages/writeups/why2025-meshtastic). Its "ESP32-C4" for the UI processor is wrong: PR #671 and the `esptool --chip esp32p4` command on [peetz0r.nl/badge](https://peetz0r.nl/badge) show an ESP32-P4.
- No source gives the number of WHY2025 badges that joined a Meshtastic or MeshCore mesh, at WHY2025 or at 39C3 (homelib run plus my own searches).

**BornHack 2026 (Denmark, Jul 2026): Cyber Ægg**
- An nRF52840 with a Semtech LoRa module and e-paper, described as "both a desktop clock/calendar, and a MeshCore node" — [Hackaday, 17 Jul 2026](https://hackaday.com/2026/07/17/the-bornhack-2026-cyber-aegg-is-a-badge-with-a-life-afterwards/)
- The firmware is Rust/Embassy with a no_std port of the MeshCore packet protocol and an SX1262 radio. Default radio settings are EU/UK Narrow: 869.618 MHz, 62.5 kHz, SF8, CR 4/5, 22 dBm, "Client repeat off". It speaks the MeshCore companion protocol over BLE, including `SET_FLOOD_SCOPE` — [bornhack-firmware-2026 README](https://codeberg.org/Ranzbak/bornhack-firmware-2026)
- Hardware goal: run "the whole duration of the BornHack camp on one battery charge (One week)" — [bornhack2026-hardware](https://codeberg.org/Ranzbak/bornhack2026-hardware). The number of badges is not stated.

**Other events**
- Burning Man 2025 (informal, not an official tally): "1,606 nodes on the playa", with a Tuesday peak of 28,817 packets and 1,189 messages. The author's own four nodes saw 3.6 % channel utilisation. "Some camps planned 5 router nodes and only 1 was up by the end of the burn" — [Burners Without Borders (Frank Cohen)](https://burnerswithoutborders.org/projects/meshtastic-meets-burning-man/)
- Neotropolis 2025, a cyberpunk LARP in the Mojave: "374 players played 3,838 matches over five days". Each ESP32 node reports scores to a scoreboard over Wi-Fi, and duels run as serial over an audio-jack cable — [Hackaday, 26 Nov 2025](https://hackaday.com/2025/11/26/elli-furedy-brings-cyberpunk-games-to-life/). The count of 202 devices comes only from the homelib video summary (**unverified**).
- 39C3: a "Meshcore & Meshtastic for Hackers" workshop with a €140 kit (Retia) — [39C3 hub](https://events.ccc.de/congress/2025/hub/en/event/detail/meshcore-meshtastic-for-hackers-set-up-configure-d)

### Inferences
- **Supercon's load was tiny next to Herz-Schwarm's.** By the Semtech formula, a 128-byte chat frame at SF7/500 kHz with a 16-symbol preamble takes about 56 ms on air, and about 112 ms at the EU 250 kHz setting (my arithmetic). Traffic existed only when people typed. "Flawless" therefore says nothing about 300 badges beaconing at several hertz. Even one chat message a second event-wide, with three relayed copies, would occupy about 22 % of the US channel.
- The Supercon stack is essentially the design the report already proposes for effects: a bounded flood (TTL), "seen" deduplication, Trickle-style suppression with k = 1, queue-based shedding of relayed traffic, and low TX power as the congestion lever.
- The TTL change from 3 to 8 for Europe suggests that 3 hops did not reach far enough at 9 dBm in the Lecco venue. Nobody stated a reason, so this is speculation.
- **Two code-level hazards worth avoiding (my reading of the code):**
  - (a) While CAD reports activity, `send()` re-scans continuously. Once the channel is free it waits a random 0–10 ms and transmits without re-checking. Every badge queued behind the same packet therefore fires within a 10 ms window, about two LoRa preambles.
  - (b) Deduplicating on a 16-bit checksum over 100 minutes produces false duplicates once thousands of messages have passed.
  - Herz-Schwarm relays should back off by at least one frame time, and should deduplicate on a sender ID plus a sequence number of 24–32 bits over a short window.
- `setPaConfig(1, 0, 1)` sets deviceSel = 1, the SX1261 low-power PA configuration in the SX126x command set. On SX1262 hardware that may radiate far less than the nominal 9 dBm, which would fit "microwatts". This is **unverified**; nobody published a measurement.
- WHY2025 shows that putting a LoRa radio on 2,500 camp badges does not by itself create a mesh. The software arrived weeks later, needed soldering, and left no evidence of scale.
- BornHack's MeshCore badges, MeshCore's official EU preset (section 3), Meshtastic's EU default (869.525 MHz/250 kHz) and Hackaday Europe's custom mesh (869.525 MHz/250 kHz) all sit in 869.4–869.65 MHz. A badge LoRa backbone at a 2027 CCC camp should expect co-channel traffic from attendee nodes.
- Burning Man's 1-of-5 surviving routers is a reminder that field infrastructure fails. Herz-Schwarm relays need power monitoring and a heartbeat that the base can see.

### Gaps
- No delivery, latency, duplicate, channel-utilisation or battery data exists from Supercon 2025, Hackaday Europe 2026, WHY2025 or BornHack 2026. The Supercon battery capacity is unknown.
- Whether the Supercon PA setting really limited output to microwatt level has not been measured.
- How many WHY2025 badges ran any mesh firmware is unknown.

## 2. ESP-NOW at scale, wake windows and Long Range

### Takeaway
Neither the homelib material nor fresh searches turned up a measurement of ESP-NOW broadcast with more than 13 nodes. Two Espressif primary sources are new to this project.

The first is the coin-cell demo. Its coin cell powers a transmit-only, power-gated switch, not the bulb, so it offers no pattern for a listening badge.

The second is Espressif's rule for reaching a sleeping ESP-NOW receiver without any phase sync. The bridge example uses a 200 ms wake interval with a 110 ms window. The sender retries at gaps shorter than the window, and the retries together span the off-time.

LR is documented again in the current ESP-IDF Wi-Fi driver overview, but whether one receiver can decode both LR and 1 Mbps ESP-NOW frames is still undocumented.

### Cited findings
- **Coin-cell demo:**
  - The switch is an ESP32-C2 on a CR2032.
  - The README claims "65000 packets", or 2.5 years at 50 presses a day.
  - The bulb is an ordinary DevKit receiver whose sdkconfig enables no power saving.
  - — [coin_cell_demo README](https://github.com/espressif/esp-now/blob/master/examples/coin_cell_demo/README.md); [bulb sdkconfig.defaults](https://github.com/espressif/esp-now/blob/master/examples/coin_cell_demo/bulb/sdkconfig.defaults)
- **Switch power design:**
  - Pressing the button applies power, and releasing it cuts power entirely; capacitor leakage is about 1.5 µA.
  - Config: `CONFIG_ESPNOW_LIGHT_SLEEP` with 30 ms of light sleep between retries, `WAIT_ACK_DURATION` 20 ms, `RETRANSMISSION_TIMES` 2 (3 sends in total), `DATA_FAST_ACK`, and `AUTO_CHANNEL_SENDING`, which retries channel by channel until an ACK arrives.
  - Measured on V1 hardware with IDF 5.2.1: a press takes about 126 ms at about 21 mA average. The transmission itself takes about 16 ms at about 75 mA. With three transmissions a press takes 227 ms at about 32 mA.
  - The default country code "01" allows only channels 1–11.
  - — [button_in_matter_bridging.md](https://github.com/espressif/esp-now/blob/master/examples/coin_cell_demo/switch/docs/button_in_matter_bridging.md); [switch sdkconfig.defaults.v2](https://github.com/espressif/esp-now/blob/master/examples/coin_cell_demo/switch/sdkconfig.defaults.v2)
- **Receiver side (ESP-NOW Matter bridge):**
  - Wake interval 200 ms and window 110 ms.
  - Rules: T_tx-gap < T_wake-window, and N × T_tx-gap > T_wake-interval − T_wake-window. In the example, 50 ms < 110 ms and 100 ms > 90 ms.
  - Idle current is about 51 mA on an ESP32-C3-DevKitM-1 that is connected to an AP with modem sleep on.
  - Wi-Fi power save and ESP-NOW power save are "two independent" mechanisms, and the default interval of 0 is recommended for Wi-Fi + BT coexistence.
  - — [esp-now-bridge-with-button.md](https://github.com/espressif/esp-matter/blob/main/examples/bridge_apps/esp-now_bridge_light/docs/esp-now-bridge-with-button.md)
- **LR in the current docs:** the LR text has moved to the Wi-Fi driver overview.
  - It describes an "802.11 BGNLR" mode. A station with LR enabled but not LR-only stays compatible with traditional 802.11, and the doc gives the AP/STA negotiation table.
  - "The CCA and backoff process in LR mode are consistent with 802.11 specification", and traditional devices detect LR through CCA.
  - The "+4 dB, 2–2.5×" claim is still there. Nothing covers ESP-NOW reception of both LR and 1 Mbps frames in BGNLR mode.
  - — [ESP-IDF latest, Wi-Fi driver overview (S3)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/wifi-driver/overview.html)
- Rate-API ordering bug IDFGH-10505: calling `esp_wifi_config_espnow_rate(WIFI_IF_STA, WIFI_PHY_RATE_LORA_500K)` before `esp_now_init()` asserted, while calling it after worked. Espressif said a fix was being merged (Aug 2023) — [espressif/esp-idf#11751](https://github.com/espressif/esp-idf/issues/11751)
- Mesh-NOW (NellowTCS): MIT licence, ESP-IDF ≥ 5.5.1. It discovers peers with periodic beacons, has a configurable TTL, and defines 7 chat-oriented message types (beacon, chat, direct, ACK, group, presence, typing). DMs retry 3 times with a 2 s timeout, AES-128-GCM is optional, and the wire format is MessagePack. It has 6 stars, one author and no performance data — [NellowTCS/Mesh-NOW](https://github.com/NellowTCS/Mesh-NOW)
- WLED notifier: a "Sends notifications twice" option for lossy links, 8 sync groups, and receivers that do not adopt the last sender's state after boot until a new packet arrives — [WLED UDP notifier](https://kno.wled.ge/interfaces/udp-notifier/)

### Inferences
- The coin-cell demo confirms that transmitting is cheap. One send costs about 16 ms × 75 mA ≈ 0.33 µAh on a C2. It says nothing about receive duty cycling, which is the badge's real cost.
- **A phase-free fallback for wake windows.** With a window of at least half the interval, a packet repeated ⌈(I − W)/gap⌉ + 1 times at gaps shorter than W always lands in a window. For rare base commands that costs 2–3 frames per command, which is negligible. For neighbour beacons it does not help: any one beacon lands in a given neighbour's window only with probability W/I.
- By my arithmetic from glenn20's FeatherS3 figures (103 mA radio on, 43.8 mA radio off), unsynchronised 110/200 ms windows (55 %) would put the S3 near 76 mA. That is about 27 mA below always-on, and lifts the capped typical-crowd runtime from 6.0 h to roughly 7.2 h. This is less than the 8–10 h of beat-locked windows, but it needs no phase control. In exchange, each neighbour hears only about 55 % of beacons, so RSSI medians need about 1.8× as many beacons.
- One-shot commands do not scale. If each badge receives a single base broadcast with p = 0.99 independently, all 300 receive it only 4.9 % of the time (0.99^300). Losses from bodies and distance are correlated, so reality is worse. This supports the report's "newest-wins state, re-broadcast on a timer" over event-style commands.
- The ESP32-C3 "invalid rate" report cited in the report looks like the same API-ordering class as IDFGH-10505, so it is weak evidence against mixed LR/1 Mbps operation. A bench test is still required.
- Mesh-NOW joins zh_network and mesh_now as single-author chat meshes. Its MessagePack framing and periodic beacons add overhead, so it is not a fit for the swarm.

### Gaps
- Mixed LR + 1 Mbps broadcast reception is still undocumented and untested.
- No API was found to set the phase of the connectionless wake interval. Espressif's own material sidesteps the problem with long windows plus sender retries.
- There are still no data on broadcast loss against node count (50–500 nodes).

## 3. LoRa backbone software: MeshCore KISS modem, presets, scoping, Meshtastic features

### Takeaway
MeshCore's KISS modem firmware turns any supported LoRa board into a raw-packet modem on a 115200-baud serial link. It adds commands for radio configuration, channel-busy checks, airtime estimates and the noise floor. That makes it a ready-made base-station or relay radio for Herz-Schwarm's own packet format, without running the MeshCore mesh.

MeshCore's packet format now supports region-scoped floods ("transport codes"). Its official EU preset is 869.618 MHz / SF8 / 62.5 kHz / CR 4/8, and the 869.525 MHz SF11 preset is marked deprecated, which resolves the conflict in lora_subghz.md.

Meshtastic's "zero-cost hops" let a backbone of favourite routers relay without spending hop budget, a model for badge relays. The simeononsecurity comparison has the licences reversed and is not reliable.

### Cited findings
- **KISS modem:**
  - Serial: 115200 8N1 with KA9Q framing.
  - Data frames are raw packets of at most 255 bytes; larger frames are "silently dropped".
  - Only one TX may be pending; a second Data frame gets Error TxBusy.
  - Unsolicited TxDone, and RxMeta (SNR × 4 and RSSI) after every received frame.
  - p-persistent CSMA with defaults TXDELAY 50 (× 10 ms = 500 ms), Persistence 63 and SlotTime 10 (100 ms).
  - SetHardware extensions: SetRadio (frequency, bandwidth, SF, CR), SetTxPower, IsChannelBusy, GetAirtime(length), GetNoiseFloor (recalibrated every 2 s), GetStats (RX, TX, errors), GetBattery, and Ed25519/X25519/AES-128 helpers.
  - Encryption is AES-128 with HMAC-SHA256 "truncated to 2 bytes". The page does not mention duty-cycle enforcement.
  - — [kiss_modem_protocol.md](https://github.com/meshcore-dev/MeshCore/blob/main/docs/kiss_modem_protocol.md)
- **Packet format:**
  - Route types are flood and direct, each optionally with 4-byte transport codes; `transport_code_1` is "calculated from region scope".
  - The path is at most 64 bytes, with 1–3-byte hashes per hop and up to 63 hops. The payload is at most 184 bytes.
  - Version 1 uses 1-byte hashes and a 2-byte MAC. A future v2 is described as "e.g., 2-byte hashes, 4-byte MAC".
  - — [packet_format.md](https://github.com/meshcore-dev/MeshCore/blob/main/docs/packet_format.md)
  - `CIPHER_MAC_SIZE 2` and `MAX_TRANS_UNIT 255` — [MeshCore.h](https://github.com/meshcore-dev/MeshCore/blob/main/src/MeshCore.h)
- **Library use:** the repo root has `library.json` and `build_as_lib.py`, a PlatformIO extra script that picks helpers per platform (ESP32, nRF52, RP2040, STM32). Contributors may not allocate memory dynamically after setup. v1.18.0 came out on 15 Oct 2026 — [MeshCore repo](https://github.com/meshcore-dev/MeshCore); [releases](https://github.com/meshcore-dev/MeshCore/releases)
- **Official presets** from the MeshCore app API:
  - "EU/UK (Narrow) 869.618MHz / SF8 / BW62.5 / CR8"
  - "EU/UK (Deprecated) 869.525MHz / SF11 / BW250 / CR5"
  - Netherlands: 869.618 MHz / SF7 / 62.5 kHz / CR5. Switzerland: 869.618 MHz / SF8 / CR8.
  - Presets are "just suggestions".
  - — [api.meshcore.nz/api/v1/config](https://api.meshcore.nz/api/v1/config), described in [radio_presets.md](https://github.com/meshcore-dev/MeshCore/blob/main/docs/radio_presets.md)
- **MeshCore usability:** "All of the official MeshCore clients are closed-source and proprietary"; only the firmware and protocol are open. The author's suburban range was about five blocks — [mtlynch.io, 2 Dec 2025](https://mtlynch.io/first-impressions-of-meshcore/). A Hackaday reader commented that a useful mesh needs 2–4 repeaters per km² (**unverified**, one comment) — [Hackaday, 6 Dec 2025](https://hackaday.com/2025/12/06/lessons-learned-after-trying-meshcore-for-off-grid-text-messaging/)
- **Meshtastic zero-cost hops** (17 Nov 2025): a favourited ROUTER or ROUTER_LATE relay keeps the remaining hop count when the previous relay was also a favourited router. Infrastructure roles need firmware ≥ 2.7.11. The motivation is that short, fast presets run out of hops in dense metro meshes — [Meshtastic blog](https://meshtastic.org/blog/zero-cost-hops-favorite-routers/)
- **Urban LoRa reality:** a 1.9 km link between two houses got through only occasionally and needed an intermediate node, against about 9 km over marshland. An "inordinate number of bad packets" pointed to a noisy RF environment — [Hackaday, 9 Oct 2025](https://hackaday.com/2025/10/09/meshtastic-a-tale-of-two-cities/)
- **simeononsecurity guide** (26 Jun 2026): it states "Meshtastic uses a BSD-style license. MeshCore uses GPL." GitHub shows the reverse: MeshCore is MIT and Meshtastic firmware is GPL-3.0 (coordinator-verified). The guide also treats "1% duty cycle under ETSI" as the general EU rule, ignoring the 10 % sub-band, and cites no dense-network benchmark — [simeononsecurity](https://simeononsecurity.com/articles/meshcore-vs-meshtastic-comparison-guide/)

### Inferences
- **A base-station LoRa option with no driver work.** Attach a Heltec V4 or similar board running MeshCore's MIT-licensed KISS firmware to the existing ESP32-S3 base over UART. The base can then send and receive Herz-Schwarm's own packets of up to 255 bytes. It can keep its 10 % duty-cycle books with GetAirtime and survey the sub-band with GetNoiseFloor and IsChannelBusy. TXDELAY must come down from its 500 ms default, and the base firmware has to enforce the duty cycle itself.
- A 2-byte MAC (1 in 65,536 forgeries per attempt) is too short for packets that trigger swarm-wide effects. Section 4 argues for 8 bytes or a signature.
- MeshCore's region-scoped floods and Meshtastic's zero-cost hops map onto two features of protocol v2. Effect packets should carry a zone or scope byte. Relays should count infrastructure hops separately from the badge TTL, so a packet relayed across the site still has its full badge-to-badge budget left.
- The backbone frequency matters. MeshCore's EU Narrow channel (869.587–869.649 MHz) is the one attendee nodes will use. A Herz-Schwarm backbone could sit elsewhere in 869.40–869.65 MHz and still be legal, but only a site survey shows what is free.

### Gaps
- The KISS modem's behaviour under EU duty-cycle limits, and its latency with TXDELAY at 0, are not documented.
- No node counts exist for MeshCore EU Narrow at BornHack 2026 or 39C3.

## 4. Security of base-station and swarm packets

### Takeaway
Two precedents and two cautionary cases shape how Herz-Schwarm should authenticate base packets.

The precedents are Supercon's signed config overrides (organisers can push any setting to every badge, but with RSA-1024 and, in my reading, no replay protection) and ESPHome packet_transport's rolling code (a 64-bit counter whose upper half is saved to flash only at boot).

The cautionary cases are MeshCore's 2-byte MAC and Meshtastic's silent downgrade (CVE-2025-53627).

A shared HMAC key sits on every badge and can be dumped. A public-key signature avoids that, at a modest cost in airtime.

### Cited findings
- **Supercon CONFIG_OVERRIDE:** the signature covers key + value only. The receiver writes the value straight to config flash. The README lists spoofing and the small RSA key as known issues — [config_manager.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/apps/config_manager.py); [firmware README](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/README.md)
- **ESPHome packet_transport:**
  - Encryption: XXTEA modified to a 256-bit key. It protects against reading and spoofing but not against replay. The page notes XXTEA is "susceptible to a chosen-plaintext attack", which it says is not possible in this application.
  - Not encrypted: the sender node name and the initial ping-pong key request.
  - Rolling code: 64 bits. The upper 32 bits are incremented and saved to flash at provider reboot and when the lower half overflows. The consumer rejects codes it has seen and keeps none in flash. Encryption is required.
  - Ping-pong: a 32-bit nonce. It needs a two-way link, and "a malicious node overwriting a valid ping-pong key" can make legitimate packets be rejected (DoS).
  - The default `update_interval` is 15 s, and only sensor and binary-sensor states are carried (no raw payload is documented).
  - — [ESPHome Packet Transport](https://esphome.io/components/packet_transport/)
- **MeshCore:** AES-128 with HMAC-SHA256 truncated to 2 bytes in v1 — [packet_format.md](https://github.com/meshcore-dev/MeshCore/blob/main/docs/packet_format.md); [kiss_modem_protocol.md](https://github.com/meshcore-dev/MeshCore/blob/main/docs/kiss_modem_protocol.md)
- **CVE-2025-53627:** Meshtastic 2.5.0 up to (but not including) 2.7.15 silently falls back to channel-key AES-CTR when the `pki_encrypted` flag is absent. Anyone holding the channel key can forge DMs that display as PKI-encrypted. CVSS 5.3; fixed in 2.7.15 — [CVE record](https://cveawg.mitre.org/api/cve/CVE-2025-53627). stridetastic ships a Grafana dashboard that detects these downgrade attempts — [stridetastic](https://github.com/0wulf/stridetastic)
- **Fri3d "Gotcha" (design only, no code):** holding a SHA-256 preimage proves two badges were close. The backend uses plain HTTP with HMAC-signed requests, since the game needs authenticity rather than secrecy — [steeman.be](https://steeman.be/posts/building-fri3d-friends/)

### Inferences
- **A concrete scheme for protocol v2's base packets (my design, not from a source):**
  - A boot epoch persisted on the base, ESPHome-style.
  - A per-packet counter.
  - The packet's swarm timestamp.
  - Either an 8-byte truncated HMAC-SHA256 or an Ed25519 signature.
- **Acceptance rules for badges:**
  - Accept a counter only if it is higher than the last one seen from that base.
  - Badges reboot without persisted state, so also reject packets whose timestamp falls outside a few beats of the current swarm time.
  - Once a badge has seen authenticated base packets, ignore unauthenticated control packets. This is the CVE-2025-53627 lesson: no silent fallback.
- **HMAC versus signature:** with an HMAC, anyone who dumps one badge's flash can forge viruses and resets. With Ed25519, as Supercon did with RSA and MeshCore does with Ed25519, badges hold only the public key.
- **Airtime cost, by my arithmetic:**
  - 17-byte payload today: 0.72 ms at 1 Mbps, 0.14 ms at 6 Mbps.
  - With an 8-byte counter and an 8-byte HMAC (33 bytes): about 0.85 / 0.16 ms.
  - With an 8-byte counter and a 64-byte signature (89 bytes): about 1.30 / 0.23 ms.
  - Either is negligible for a few base packets a second. Ed25519 verification time on the S3 under Arduino still needs measuring.
- Supercon's CONFIG_OVERRIDE is the report's network-wide "nice" knob already built. It should also carry the counter and an expiry, and badges should apply only a whitelisted set of keys.

### Gaps
- Ed25519 verify time and code size on the ESP32-S3 with Arduino-ESP32 3.x have not been measured.
- Flash encryption or secure boot on the badge, which would make an HMAC key harder to extract, has not been evaluated.

## 5. Tools for planning and measuring

### Takeaway
No tool in the library simulates an ESP-NOW or 802.11b broadcast swarm. Meshtasticator covers LoRa only, which makes it useful for the backbone.

For the camp, the best observability model is stridetastic's pipeline: ingest into TimescaleDB, analyse in Grafana, and capture PCAP-NG for Wireshark. A few ESP32 sniffers on the badge channel would feed it.

Paxcounter/libpax cannot be reused as is. It counts only randomised (locally administered) MACs, so it ignores ESP32 badges, and it counts devices rather than airtime.

### Cited findings
- **Meshtasticator:**
  - Discrete-event mode mimics Meshtastic's radio logic on a LoRaSim-derived PHY. Collisions depend on frequency, SF, timing and received power.
  - Path-loss models: log-distance, Okumura-Hata variants and 3GPP. The MAC is listen-before-talk with random or SNR-based delays.
  - Batch runs and plots are supported.
  - The interactive mode runs the real Meshtastic Linux-native app.
  - Preset table: 250, 125 and 62.5 kHz presets only, no Short Turbo. Messages are generated with an exponential distribution around a configurable mean period.
  - Licence CC BY 4.0, with commits as recent as July 2026. Its example plot shows more hops reaching more nodes but lowering "usefulness".
  - — [Meshtasticator](https://github.com/GUVWAF/Meshtasticator); [DISCRETE_EVENT_SIM.md](https://github.com/GUVWAF/Meshtasticator/blob/master/DISCRETE_EVENT_SIM.md)
- **stridetastic:**
  - GPL-3.0, Docker Compose.
  - Ingests MQTT, serial and TCP (plus WebSocket) into TimescaleDB hypertables.
  - A Next.js dashboard shows topology and links (bidirectional or one-way).
  - PCAP-NG capture with per-frame annotations, plus a Wireshark Lua dissector.
  - One-shot, reactive and periodic probes and traceroutes.
  - Grafana dashboards for network health and CVE-2025-53627.
  - — [stridetastic](https://github.com/0wulf/stridetastic)
- **meshShark:** an ESP32 Meshtastic LoRa header sniffer for Heltec V2/V3. It prints from, to, ID, hops, RSSI and SNR, and is meant for comparing antennas. GPL-3.0 — [ErikDorstel/meshShark](https://github.com/ErikDorstel/meshShark)
- **Supercon on-badge tools:**
  - BadgeShark, a promiscuous capture of BadgeNet frames with filters — [badgeshark.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/apps/badgeshark.py).
  - An ImHex pattern for the packets — [lora.hexpat](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/lora.hexpat).
  - A Spectrum app (an SX1262 instantaneous-RSSI sweep from 860 to 886 MHz, modified for Hackaday Europe) — [spectrum.py](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/firmware/badge/apps/spectrum.py)
- **Paxcounter / libpax:**
  - The Wi-Fi sniffer captures management and data frames, hopping channels every 0.5 s across all channels. BLE scanning uses an 80/80 ms window and interval. An RSSI limit is optional — [paxcounter_orig.conf](https://github.com/cyberman54/ESP32-Paxcounter/blob/master/shared/paxcounter_orig.conf); [wifiscan.cpp](https://github.com/dbinfrago/libpax/blob/master/lib/libpax/wifiscan.cpp)
  - `mac_add()` returns early unless the locally administered bit is set, and uses the last two MAC bytes as a 16-bit ID — [libpax.cpp](https://github.com/dbinfrago/libpax/blob/master/lib/libpax/libpax.cpp). It remembers at most 65,535 IDs in 8 KB — [libpax README](https://github.com/dbinfrago/libpax)
  - MAC addresses are never stored persistently — [Paxcounter README](https://github.com/cyberman54/ESP32-Paxcounter)
- **Espressif `wireless_debug` example:** collects running logs from many devices over ESP-NOW, with wifi_scan, ping and ESP-NOW iperf commands and a web server. The debug receiver must share the devices' channel — [wireless_debug README](https://github.com/espressif/esp-now/blob/master/examples/wireless_debug/README.md)

### Inferences
- **A camp measurement kit:**
  - 3–5 ESP32-S3 boards in promiscuous mode, fixed on the badge channel, with one hopping across 1–13.
  - Each logs per frame: timestamp, sender MAC (the OUI separates Espressif badges from phones), length, PHY rate and RSSI.
  - They stream over Ethernet or MQTT to TimescaleDB and Grafana, stridetastic-style, which yields airtime share per second, the badge count heard per sniffer and loss per sequence number.
  - A libpax-derived counter of randomised MACs adds an estimate of phone density.
  - An SX1262 RSSI sweep (Supercon's Spectrum pattern) or KISS GetNoiseFloor surveys 869.4–869.65 MHz before the backbone channel is chosen.
- A Wireshark or ImHex dissector for SyncPacket and protocol v2 already pays off in the 12-badge load test.
- Meshtasticator suits only the LoRa backbone (base plus 2–6 relays, with a custom 250 kHz SF7 modem entry). For ESP-NOW, the 12-badge load test plus the report's ALOHA/CSMA arithmetic remains the planning tool.

### Gaps
- No ESP-NOW or 802.11b broadcast-swarm simulator was found (ns-3's Wi-Fi model was not evaluated).

## 6. Hardware and safety

### Takeaway
The WHY2025 fire hazard came from unprotected 18650 cells on a bare PCB. The cell traces sat 0.4 mm from ground under 10–30 µm of solder mask, and in a 20 A test the badge's protection reacted too slowly. Supercon's antenna connectors snapped because only one side had been soldered. Both lessons apply directly to the Herz-Schwarm battery badge. In my reading of DESIGN.md and BOM.md it has no on-board fuse or cell-protection IC and relies on the cell's own protection board.

### Cited findings
- **WHY2025 fire hazard advisory** (Juerd and co-signatories; written 3 Aug, published 5 Aug 2025):
  - Cells: two 18650s in parallel, unprotected, able to deliver more than 20 A into a short. No housing or carry case.
  - Copper: the "+" and "−" traces on the outer copper are 0.4 mm from the GND plane. The only insulation is solder mask, about 10–30 µm thick.
  - Cell holders: the holder tabs sit on undersized pads, and tolerances exceed the 0.4 mm clearance. One GND joint is about 0.6 mm from a "+" pad. One cell's "+" trace crosses the board before reaching its polyfuse.
  - Test: with a 20 A supply the protections were too slow, and a MOSFET glowed "yellow glowing hot".
  - Mitigation: on 20 July, Team:Badge decided to epoxy only the exposed joints.
  - By comparison, SHA2017 and MCH2022 used protected cells insulated with about 120 µm of kapton.
  - — [wiki.why2025.org/Badge/Fire_hazard](https://wiki.why2025.org/Badge/Fire_hazard)
  - Organisers handed out a disclaimer leaflet and added a last-minute epoxy coat. The original badge team had resigned en masse early in 2025 — [Hackaday, 12 Aug 2025](https://hackaday.com/2025/08/12/when-a-badge-misses-the-mark-why-2025/)
  - The 18650 holders "come off suspiciously easily", and a protected 104050 pouch cell is recommended as a replacement — [peetz0r.nl/badge](https://peetz0r.nl/badge)
- Supercon: SMA connectors broke off because only one side was soldered. The workaround is to solder both sides and unscrew the antenna for transport — [issue #53](https://github.com/Hack-a-Day/2025-Communicator_Badge/issues/53)
- WHY2025: users had to solder the antenna connector themselves, and running LoRa firmware without an antenna risks the PA — [MeshCore PR #671](https://github.com/meshcore-dev/MeshCore/pull/671); [peetz0r.nl/badge](https://peetz0r.nl/badge)
- BornHack: TX defaults to 22 dBm on the claim that the badge antenna "is not fully efficient, so radiated power stays within the band limit" (the author's claim, not a measurement) — [bornhack-firmware-2026 README](https://codeberg.org/Ranzbak/bornhack-firmware-2026)
- Solar relays: a garden-light panel "can't keep an ESP32 with a radio going all day", while a commercial charger and an off-the-shelf panel coped even in Alaska. No wattages were given — [Hackaday, 17 Sep 2025](https://hackaday.com/2025/09/17/the-practicality-of-solar-powered-meshtastic/)
- Herz battery badge (my reading of DESIGN.md and BOM.md): the BOM tells the buyer to "Ask for a protection board" on the 103030 1000 mAh pouch cell. The power path is a TP4056 charger, a Q103 reverse guard and a JST PH connector, and no fuse is listed. Full white at 2.3 A would exceed the JST's 2 A rating, so firmware must never allow it — [BOM.md](../../herz_badge/BOM.md); [DESIGN.md](../../herz_badge/DESIGN.md)

### Inferences
- **Battery safety:**
  - Make a cell protection board a hard requirement, and check every incoming cell for it.
  - Insulate the cell and its pads on the back of the badge with kapton or a printed cover.
  - Keep VBAT copper away from exposed GND and board edges.
  - The WHY2025 test shows that a polyfuse alone reacts too slowly, so the cell's protection board stays the primary safeguard.
- Relays and the base on masts need strain relief on SMA/u.FL connectors, and should be transported with the antenna off.
- For an 868 MHz antenna on a badge-sized board there is nothing new. WHY2025's 1.7:1 SWR was achieved on a much larger board.

### Gaps
- None of the badges above has a published measured runtime.

## 7. What changes in the report

**Lead paragraph ("Quieter radios let hundreds of hearts sync")**
- No change to the verdict. Optionally add one clause: the 2025–26 event badge meshes (Supercon, WHY2025, BornHack) published no delivery data, so Herz-Schwarm's camp logging would be the first such dataset.

**Airtime, not ESP-NOW, caps today's protocol near 20 badges**
- Add: a fresh search (Oct 2026) still found no ESP-NOW broadcast measurement beyond 13 nodes.
- Add: one-shot base commands do not scale. At 99 % per-badge delivery, all 300 badges receive a single broadcast only 4.9 % of the time, which supports newest-wins state that is re-broadcast on a timer.

**No off-the-shelf mesh survives 300 badges at 20 Hz**
- **Correct the Supercon sentence.**
  - Replace "whose mesh repeats 'anything they hear' … No post-mortem has been published".
  - New facts: the shipped firmware was a bounded flood with TTL 3, a 16-bit-checksum duplicate cache, cancellation after hearing one other repeat, CAD before TX, and relays dropped when the queue is half full. It ran on 906.25 MHz/500 kHz/SF7 at 9 dBm with the PA set low, and carried only human-typed chat.
  - The organisers say it "worked flawlessly, even on microwatts" but published no data.
  - For Hackaday Europe 2026 the same badges ran at 869.525 MHz/250 kHz with the chat TTL raised to 8.
- **Add WHY2025.** About 2,500 badges carried an SX1262 (Ai-Thinker RA-01SH) that needed two bodge wires, a soldered antenna connector and a co-processor reflash. There is no evidence of how many joined a mesh.
- **Add BornHack 2026.** Its nRF52840 + SX1262 MeshCore badge defaults to EU/UK Narrow (869.618 MHz) with client repeat off. It is a European camp badge that shipped as a mesh node out of the box, with no soldering or reflashing.
- **Optionally add Burning Man 2025** (informal): 1,606 nodes, and only 1 of 5 planned routers still up at the end.
- **MeshCore sentence:** keep "channel messages always flood", but add that floods can be region-scoped with transport codes, and that the official EU preset is 869.618 MHz / SF8 / 62.5 kHz / CR 4/8, with 869.525 MHz SF11/250 kHz deprecated.
- **Add Meshtastic zero-cost hops** (≥ 2.7.11) as the model for relays that do not consume the badge TTL.
- **Security paragraph:**
  - Extend the HMAC advice. Every badge holds an HMAC key, and dumping one badge's flash is enough to forge base packets. Prefer an Ed25519 signature (64 bytes, about 0.23 ms at 6 Mbps), or at least an 8-byte HMAC; MeshCore's 2-byte MAC is the counter-example.
  - Add a base boot epoch persisted to flash (as ESPHome's rolling code does) plus a per-packet counter, a swarm-time window for badges that rebooted, and no silent fallback to unauthenticated packets (CVE-2025-53627).
  - Cite Supercon's signed CONFIG_OVERRIDE as a working precedent for a remote throttle, noting it lacked replay protection.

**Range belongs on masts, not in louder badges**
- **LR paragraph:**
  - The current ESP-IDF Wi-Fi driver overview documents BGNLR mode and says LR uses standard 802.11 CCA and backoff, so it coexists with normal Wi-Fi.
  - It still says nothing about one ESP-NOW receiver decoding LR and 1 Mbps frames at once.
  - The C3 "invalid rate" report resembles the rate-API call-order bug IDFGH-10505, so it is weak evidence. The bench test stays.
- **868 MHz paragraphs:**
  - Replace "shares its 250 kHz band with Meshtastic" with: shares it with Meshtastic's EU default (869.525 MHz/250 kHz), MeshCore's EU Narrow channel (869.618 MHz/62.5 kHz) as used by BornHack badges and attendee nodes, and custom badge meshes such as Hackaday Europe's 869.525 MHz/250 kHz.
  - Add: survey the sub-band on site before choosing parameters, with an SX1262 RSSI sweep or KISS GetNoiseFloor.
- **Add the MeshCore KISS modem** (MIT) as an off-the-shelf raw-LoRa modem for the base or relays over UART. It offers SetRadio, IsChannelBusy, GetAirtime and GetNoiseFloor. Its 500 ms default TXDELAY must be lowered, and it does not enforce the duty cycle. It is an alternative to ESPHome `sx126x`.
- Optionally add the Hackaday urban example (a 1.9 km link only occasionally getting through) to reinforce mounting relays high.

**The always-on receiver is 58 % of the new badge's battery**
- **Wake-window paragraph.** Keep "no documented API sets the window's phase", but add Espressif's own phase-free rule.
  - The ESP-NOW Matter bridge listens 110 ms of every 200 ms.
  - Senders repeat at gaps shorter than the window, so that N × gap exceeds the off-time.
  - By my arithmetic that fallback puts the S3 near 76 mA, giving roughly 7.2 h against 6.0 h, with no phase lock. The cost is that neighbours hear only about 55 % of beacons.
  - Beat-locked windows (8–10 h) remain the target. The phase-free rule is the fallback and suits rare base commands.
- **Coin-cell example.** If the report or a later revision cites Espressif's coin-cell example, note that the cell powers a transmit-only, power-gated ESP32-C2 switch (126 ms at about 21 mA per press). The bulb is an always-on receiver, so the example offers no receive-side pattern.

**Keep the ESP32-S3 for Camp 2027 and rewrite the protocol**
- **Step 1, load test:** add an observability kit:
  - ESP32 promiscuous sniffers logging per-frame RSSI, rate and sequence number to TimescaleDB/Grafana (stridetastic as the model).
  - A Wireshark/ImHex dissector for the packet format.
  - Espressif's `wireless_debug` for remote logs and iperf.
  - Note that Paxcounter/libpax counts only randomised MACs, so it cannot count badges; reuse its sniffer code instead.
- **Step 2, protocol v2:** add:
  - Ed25519-signed or 8-byte-HMAC base packets with a persisted epoch and counter.
  - A signed config override as the remote "nice" knob.
  - Deduplication on sender + sequence with at least 24–32 bits (Supercon used a 16-bit checksum; 2-byte IDs collide about 50 % of the time at 300 badges).
  - A relay backoff of at least one frame time (the Supercon CAD lesson).
  - A zone/scope byte, and an infrastructure hop count kept separate from the badge TTL.
- **Step 4, range:** add an on-site 869.4–869.65 MHz occupancy survey, and relay health monitoring (Burning Man lost 4 of 5 planned routers).
- **Step 6, hardware:** add:
  - Protected cells as a hard requirement, checked on arrival.
  - Insulation of the cell and VBAT pads, and no exposed VBAT copper near GND (the WHY2025 lesson).
  - Strain-relieved antenna connectors on the base and relays (the Supercon lesson).
- **ESPHome paragraph:** add that `packet_transport` carries only ESPHome sensor states (XXTEA with rolling code and ping-pong). It cannot carry SyncPacket, so treat it as a pattern for replay protection, not a transport for the badges.
- **Board paragraph:** Meshtasticator (CC BY 4.0) can plan the LoRa backbone only.

**Conclusion**
- No change.

**Corrections to the existing notes files (outside the report)**
- prior_art.md §2: the WHY2025 radio is an SX1262 (Ai-Thinker RA-01SH), which resolves the SX1276/SX1268 conflict. About 2,500 badges were distributed. The battery issue is now verified from the official advisory (§6 above). The Supercon "no post-mortem" gap is partly filled by the firmware analysis in §1.
- espnow_wifi_mesh.md §2: the statement that the latest ESP-IDF pages "do not mention LR at all" is outdated. LR is documented at [wifi-driver/overview.html](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/wifi-driver/overview.html).
- lora_subghz.md (MeshCore EU settings): the MeshCore preset API settles the conflict. EU/UK (Narrow) is 869.618 MHz / SF8 / 62.5 kHz / CR 4/8, and 869.525 MHz / SF11 / 250 kHz / CR 4/5 is "EU/UK (Deprecated)".
- lora_subghz.md cites the simeononsecurity guide. Keep it only for "no benchmark exists", and flag that it reverses the licences and misstates the EU duty cycle.
