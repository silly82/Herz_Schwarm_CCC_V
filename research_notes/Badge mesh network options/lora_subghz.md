# LoRa and other sub-GHz radios (Meshtastic, MeshCore, raw LoRa, FSK) as a network layer for the Herz-Schwarm badge swarm

Research date: 2026-10-17. Scope: EU / Germany, a few hundred ESP32-S3 badges at a CCC camp, today on ESP-NOW (17-byte `SyncPacket`, 20 packets/s per badge, radio never sleeps, about 90 mA). Project facts used below come from the repo: the badge radio draws 88–91 mA receiving plus about 1 mA for 20 packets/s, and the LED heart draws 35 / 139 / 271 mA (quiet / typical / packed crowd) ([herz_badge/DESIGN.md §3](/Users/foz/src/Herz_Schwarm_CCC_V/herz_badge/DESIGN.md)). The planned battery badge is a 30 × 34 mm 4-layer board with an ESP32-S3FH4R2, a 2.4 GHz corner chip antenna and a 1000 mAh 103030 cell, at $8.91 in parts per board at 100 units ([git commit 253e135 / herz_badge/BOM.md](/Users/foz/src/Herz_Schwarm_CCC_V/herz_badge/BOM.md)). Badges transmit at 13 dBm because of heat; the base station transmits at 21 dBm ([todo.md](/Users/foz/src/Herz_Schwarm_CCC_V/todo.md)).

Numbers marked "computed" are my own arithmetic with the Semtech time-on-air formula (SX1261/2 datasheet §6.1.4), FSK frame arithmetic and the textbook pure-ALOHA model. They are in the Inferences sections, not presented as sourced facts.

## Overall verdict: main swarm link, long-range backbone, or not at all?

### Takeaway
Sub-GHz cannot replace ESP-NOW as the 20 Hz per-badge swarm link: EU duty cycles (0.1–10 %) and the airtime of LoRa packets allow roughly one packet per badge every few seconds, and one shared channel that covers the whole camp collapses under a few hundred talkers. It is a very good fit as a one-to-many backbone, with only the base station (plus optional relays) transmitting on 869.4–869.65 MHz at up to 500 mW ERP and 10 % duty cycle, and badges receive-only at about 5 mA (or about 1–2 mA duty-cycled) instead of about 90 mA for the always-on Wi-Fi receiver. Meshtastic and MeshCore are the wrong tool for the sync traffic itself.

### Cited Findings
- A 20-byte LoRa packet at SF7/125 kHz takes tens of milliseconds on air. The time-on-air equation and its parameters (SF, BW, CR, CRC, header, low-data-rate optimisation) are in the SX1261/2 datasheet §6.1.4 — [Semtech SX1261/2 datasheet Rev 1.2, June 2019](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- EU sub-bands for non-specific SRDs: 863–865 MHz ≤0.1 % or polite spectrum access (PSA), 25 mW ERP; 865–868 MHz ≤1 % or PSA, 25 mW; 868.0–868.6 MHz ≤1 % or PSA, 25 mW; 868.7–869.2 MHz ≤0.1 % or PSA, 25 mW; 869.4–869.65 MHz ≤10 % or PSA, 500 mW ERP; 869.7–870.0 MHz 5 mW ERP with no duty-cycle requirement (audio/video excluded) or 25 mW at ≤1 % or PSA — [ETSI EN 300 220-2 V3.2.1 (2018-06), Table B.1](https://www.etsi.org/deliver/etsi_en/300200_300299/30022002/03.02.01_60/en_30022002v030201p.pdf)
- SX1262 receive current: 4.6 mA (LoRa 125 kHz, DC-DC) or 5.3 mA in Rx Boosted mode, 8.8–10.1 mA in LDO mode — [SX1261/2 datasheet Table 3-5](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- ESP32-S3 Wi-Fi RX current is 88 mA (802.11b/g/n HT20) and 91 mA (HT40), and the 802.11b 1 Mbps sensitivity is -98.4 dBm — [ESP32-S3 datasheet v2.2, Tables 5-7 and 6-4](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf)
- Meshtastic in EU_868 runs on 869.4–869.65 MHz, 27 dBm, 10 % duty cycle over a rolling hour; Turbo (500 kHz) presets are not offered there — [Meshtastic LoRa configuration docs](https://meshtastic.org/docs/configuration/radio/lora/)

### Inferences
- Main link: no. Computed: 20 packets/s × 56.6 ms (SF7/125, 20 B) = 113 % airtime for one badge. Even FSK at 250 kbps (about 0.96 ms per 20-byte frame) needs 1.9 % per badge, above the 1 % limit of most 25 mW sub-bands, and 300 badges × 20/s × 0.96 ms ≈ 576 % load on one channel.
- Backbone: yes. A single transmitter (base station) has no collision problem, can use the 500 mW / 10 % sub-band, and badges never transmit on sub-GHz, so badge duty cycle and capacity limits disappear. Computed: 10 % of an hour allows about 1.8 packets/s at SF7/125 (20 B) or about 0.5 packets/s at SF9/125 for the whole site, enough for effect commands and a periodic global beat/phase reference.
- Global beat sync becomes possible: if the base broadcasts a phase/timestamp packet every 1–2 s, every badge on the field can lock to the same clock, instead of today's local ESP-NOW consensus. Proximity effects (RSSI between badges) still need 2.4 GHz or BLE.
- Long range is a drawback for badge-to-badge traffic: at sub-GHz every badge on the camp field hears every other badge, so there is no spatial reuse. Today's ESP-NOW design probably works partly because 2.4 GHz at chest level is short-range. ESP-NOW frame length is not sourced here; it is my estimate at about 0.5–1 ms at 1 Mbps.

### Gaps
- No field test of LoRa or FSK at a festival or camp with hundreds of bodies was found.
- No measurement of a 868 MHz antenna on a 30 × 34 mm badge was found. This could cost 5–10 dB or more; see the Range section.

## EU 863–870 MHz rules (ETSI EN 300 220, ERC 70-03, Germany): duty cycle, LBT/PSA, ERP, and the message rates they allow

### Takeaway
Most 25 mW sub-bands allow 0.1 % or 1 % duty cycle per device. Only 869.4–869.65 MHz allows 500 mW at 10 %, and 869.7–870.0 MHz allows 5 mW with no duty-cycle limit. PSA (LBT+AFA) caps on-air time at 100 s per hour per 200 kHz (2.78 %), 1 s per transmission and 100 ms off-time. Computed: a badge could send a 20-byte LoRa SF7 packet about once every 3–6 s at 1 %, against 20 per second today.

### Cited Findings
- Sub-band table (EN 300 220-2 V3.2.1 Table B.1, from EC Decision 2017/1483/EU). Band K 863–865 MHz: 25 mW ERP, ≤0.1 % or PSA. L 865–868 MHz: 25 mW, ≤1 % or PSA. M 868.0–868.6 MHz: 25 mW, ≤1 % or PSA. N 868.7–869.2 MHz: 25 mW, ≤0.1 % or PSA. P 869.4–869.65 MHz: 500 mW ERP, ≤10 % or PSA (band 54). 869.7–870.0 MHz: 5 mW ERP, "No requirement" (band 56a, audio/video excluded). 869.7–870.0 MHz: 25 mW ERP, ≤1 % or PSA (band 56b) — [ETSI EN 300 220-2 V3.2.1](https://www.etsi.org/deliver/etsi_en/300200_300299/30022002/03.02.01_60/en_30022002v030201p.pdf)
- PSA timing limits (EN 300 220-1 Table 48): minimum CCA (listen) interval 160 µs; dead time ≤5 ms; maximum transmission duration 1 s single (4 s for a dialogue or polling sequence); maximum cumulative on-time 100 s per hour per 200 kHz; minimum off-time 100 ms on the same frequency. "Longer accumulated transmission time is possible by implementing more AFA channels." — [ETSI EN 300 220-1 V3.1.1 (2017-02), clause 5.21.3.1](https://www.etsi.org/deliver/etsi_en/300200_300299/30022001/03.01.01_60/en_30022001v030101p.pdf)
- CCA threshold limit: 15 dB above the Rx sensitivity limit for ERP below 100 mW, 11 dB above for 100–500 mW — [ETSI EN 300 220-1 V3.1.1, Table 45](https://www.etsi.org/deliver/etsi_en/300200_300299/30022001/03.01.01_60/en_30022001v030101p.pdf)
- 100 s/h equals about 2.78 %; Morse Micro's EU HaLow uses this PSA allowance (2.8 %), and cites EN 300 220-2 §4.6.3.2 Table 18 — [Morse Micro community forum](https://community.morsemicro.com/t/mm8108-gb-eu-863-868-mhz-origin-of-the-2-8-duty-cycle-and-is-lbt-psa-operation-available/1918)
- 869.4–869.65 MHz may be split into 25 kHz channels or used as one channel for high-speed data — [Wikipedia, Short-range device](https://en.wikipedia.org/wiki/Short-range_device) (secondary; summarises ERC 70-03)
- Since 1 January 2018, 865–868 MHz also has four 200 kHz channels (centre 865.7, 866.3, 866.9, 867.5 MHz) for data networks at up to 500 mW ERP with adaptive power control, ≤10 % duty cycle for network access points and ≤2.5 % for other devices — [Wikipedia, Short-range device](https://en.wikipedia.org/wiki/Short-range_device). The EUR-Lex text of Decision (EU) 2018/1538 shows the same 10 % / 2.5 % structure for 874–874.4 MHz, but I did not confirm the 865–868 MHz row in the legal text — [EUR-Lex 2018/1538 consolidated](https://eur-lex.europa.eu/eli/dec_impl/2018/1538/2022-02-09/eng/pdf)
- Germany: the Bundesnetzagentur's general SRD allocation is now Vfg. 91/2025, which replaces the earlier separate allocations, including Vfg. 133/2019 (non-specific SRD), Vfg. 06/2010 (RFID 865–868 MHz) and Vfg. 45/2016 (868–870 MHz alarms) — [Bundesnetzagentur, Allgemeinzuteilungen](https://www.bundesnetzagentur.de/allgemeinzuteilungen)
- Meshtastic enforces the EU 10 % limit per node (computed every minute over a rolling hour, the node stops transmitting at the limit); `override_duty_cycle` can disable it, which "may violate regulations" — [Meshtastic LoRa config](https://meshtastic.org/docs/configuration/radio/lora/)

### Inferences
- Computed per-device budgets for a 20-byte payload (LoRa: explicit header, CRC on, CR 4/5, 8-symbol preamble; FSK: 4 B preamble + 3 B sync + 1 B length + 2 B CRC):

| Duty cycle | Airtime/h | LoRa SF7/125 (56.6 ms) | LoRa SF7/250 (28.3 ms) | LoRa SF9/125 (185 ms) | FSK 50 kbps (4.8 ms) | FSK 250 kbps (0.96 ms) |
|---|---|---|---|---|---|---|
| 0.1 % (K, N) | 3.6 s | 1 per 57 s | 1 per 28 s | 1 per 185 s | 0.21/s | 1.0/s |
| 1 % (L, M, 56b) | 36 s | 1 per 5.7 s | 1 per 2.8 s | 1 per 18.5 s | 2.1/s | 10.4/s |
| 2.78 % (PSA, per 200 kHz) | 100 s | 1 per 2.0 s | 1 per 1.0 s | 1 per 6.7 s | 5.8/s | 29/s |
| 10 % (P, 500 mW) | 360 s | 1.77/s | 3.5/s | 0.54/s | 20.8/s | 104/s |
| none (869.7–870, 5 mW) | – | channel-limited | channel-limited | channel-limited | channel-limited | channel-limited |

- The PSA row ignores the 100 ms minimum off-time on one frequency, which caps a single frequency at 10 transmissions/s; the FSK 250 kbps PSA figure (29/s) would need AFA hopping across several 200 kHz channels.
- Compared with 20 packets/s per badge today, only FSK at ≥250 kbps in a 10 % or unrestricted sub-band reaches 20/s for a single device, and 250 kbps FSK (frequency deviation 125 kHz, Rx bandwidth 500 kHz per the datasheet test condition) does not fit the 250 kHz-wide 869.4–869.65 MHz band. It fits only the wider 863–868.6 MHz bands, which are limited to 0.1–1 %.
- The 869.7–870.0 MHz sub-band (5 mW ERP, no duty cycle, 300 kHz wide) is the only sub-GHz place where badges could talk freely; 5 mW is 7 dBm ERP. Capacity, not regulation, then becomes the limit (see next section).
- Base station: 869.4–869.65 MHz at 10 % and up to 27 dBm ERP is the natural backbone channel. Meshtastic and MeshCore users at the camp will also be in this 250 kHz band (Meshtastic EU_868, MeshCore EU presets 869.525 / 869.618 MHz), so a badge backbone there shares airtime with them. The 865–868 MHz 500 mW "network access point" channels (10 % for the base station) are an alternative, if Vfg. 91/2025 implements them (not verified).
- PSA (LBT) is worse than plain duty cycle in the 10 % band (2.78 % per 200 kHz vs 10 %), but better than 0.1 % / 1 % in the 25 mW bands, and it scales with the number of AFA channels used.

### Gaps
- I could not read the frequency table of BNetzA Vfg. 91/2025 to confirm that the 865–868 MHz 500 mW networked channels and the 869.7–870 MHz 5 mW no-duty-cycle entry are implemented identically in Germany.
- EN 300 220-2 V3.2.1 (2018) and EN 300 220-1 V3.1.1 (2017) were the versions retrieved; a newer harmonised revision may exist.
- The ERC 70-03 consolidated text itself was not retrieved; the ETSI Table B.1 was used instead.

## LoRa and FSK airtime for a ~20-byte packet, and channel capacity with hundreds of nodes

### Takeaway
A 20-byte packet takes about 57 ms at SF7/125, 28 ms at SF7/250, 185 ms at SF9/125, and 1–5 ms with FSK at 50–250 kbps (computed). Pure ALOHA on one channel peaks at 18 % throughput. Computed: a few hundred LoRa SF7 badges collide heavily even at one packet per 10 s. Published LoRa scalability studies (2016–2017, single-hop LoRaWAN) put the practical limit at roughly 100–1000 nodes per gateway at very low rates (packets per tens of minutes) — orders of magnitude below 20 Hz.

### Cited Findings
- SX1262 capabilities: LoRa 18 bps to 62.5 kbps, (G)FSK/MSK up to 300 kbps — [Semtech SX126x brochure](https://www.semtech.com/uploads/common/LoRa_products_sx126x.pdf); "300 kb/s in the 869/915 MHz frequency bands" — [SX1261/2 datasheet note 5](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- RadioLib SX126x `setBitRate` accepts 0.6–300 kbps; frequency deviation 0–200 kHz; Rx bandwidth 4.8–467 kHz — [RadioLib SX126x class reference](https://jgromes.github.io/RadioLib/class_s_x126x.html)
- Co-channel rejection (capture) on SX1261/2: FSK -9 dB, LoRa SF7 5 dB, SF12 19 dB; adjacent-channel rejection LoRa 125 kHz SF7 60 dB — [SX1261/2 datasheet Table 3-8](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- Meshtastic preset data rates (theoretical, without headers or hops): Short Turbo SF7/500 kHz 21.88 kbps; Short Fast SF7/250 10.94 kbps; Short Slow SF8/250 6.25 kbps; Medium Fast SF9/250 3.52 kbps; Medium Slow SF10/250 1.95 kbps; Long Fast SF11/250 1.07 kbps (default); Long Moderate SF11/125 CR4/8 0.34 kbps. Link budgets 140–156 dB at 22 dBm — [Meshtastic radio settings](https://meshtastic.org/docs/overview/radio-settings/)
- Bor, Roedig, Voigt, Alonso (MSWiM 2016, older): "a typical smart city deployment can support 120 nodes per 3.8 ha"; LoRa scales much better with dynamic parameter selection and/or multiple sinks — [UCC research portal](https://research.ucc.ie/en/publications/do-lora-low-power-wide-area-networks-scale/)
- Haxhibeqiri et al. (Sensors 2017, older), measurement-calibrated simulation: 20-byte payload, 1 % duty-cycle-saturated traffic, SF7–12 mix over three 868 MHz channels (18 logical channels) → about 32 % loss at 1000 nodes per gateway (24 % collisions + 8 % bad CRC), against about 90 % for pure ALOHA; a single channel at a single SF saturates ("all traffic collides") at about 200 nodes. Same-SF recapture works only if the interferer arrives after the preamble, and the receiver needs the last six preamble symbols collision-free — [PMC5490692](https://pmc.ncbi.nlm.nih.gov/articles/PMC5490692/)
- A 2024 study of LoRa and Sigfox in congested environments concluded at most 100 LoRa nodes for a fixed-transmission use case in an area up to 1 km — [Sensors 2024, PMC11510795](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11510795/) (from search summary; not opened)
- Meshtastic SDR analysis of a roughly 10-node mesh: collisions appear well before 50 % utilisation, and "25 % channel utilization is actually quite busy" — [Meshtastic forum, SDR visualization of LongFast](https://meshtastic.discourse.group/t/sdr-visualization-of-new-default-longfast-channel-in-1-3/5962)

### Inferences
- Computed airtimes (CR 4/5, explicit header, CRC, 8-symbol preamble; with a 16-symbol preamble as Meshtastic uses in brackets):

| Setting | 17 B | 20 B | 48 B |
|---|---|---|---|
| LoRa SF7/125 | 51.5 (59.6) ms | 56.6 (64.8) ms | 97.5 ms |
| LoRa SF7/250 | 25.7 (29.8) ms | 28.3 (32.4) ms | 48.8 ms |
| LoRa SF7/500 (not allowed in the EU 10 % band) | 12.9 ms | 14.1 ms | 24.4 ms |
| LoRa SF8/250 | 46.3 ms | 51.5 ms | 87.3 ms |
| LoRa SF9/125 | 165 ms | 185 ms | 308 ms |
| LoRa SF9/250 | 82.4 ms | 92.7 ms | 154 ms |
| LoRa SF11/250 (Meshtastic Long Fast) | 330 (395) ms | 330 (395) ms | 535 (600) ms |
| FSK 50 kbps | 4.3 ms | 4.8 ms | 9.3 ms |
| FSK 100 kbps | 2.2 ms | 2.4 ms | 4.6 ms |
| FSK 250 kbps | 0.86 ms | 0.96 ms | 1.9 ms |

- Computed pure ALOHA (success per packet = e^(−2G), G = N × rate × airtime), 20-byte packets on one channel:
  - LoRa SF7/125: 100 nodes at 1 packet/min → 83 % success; 300 nodes at 1/min → 57 %; 300 nodes at 1 per 10 s → 3 %; 500 nodes at 1/min → 39 %. Peak whole-channel goodput ≈ 0.184 / 0.0566 s ≈ 3.3 delivered packets/s for the entire site.
  - LoRa SF7/250: 300 nodes at 1 per 10 s → 18 %; 300 nodes at 1/s → 0 %.
  - FSK 250 kbps: 300 nodes at 1/s → 56 %; 500 nodes at 1/s → 38 %; 100 nodes at 20/s → 2 %; 300 nodes at 20/s → 0 %. Peak goodput ≈ 190 packets/s per channel for the whole site.
  - LoRa SF9/125: 300 nodes at 1/min → 16 %.
- LoRa capture (5 dB at SF7) and LBT/CSMA would improve these figures somewhat, but in a crowd of moving bodies with hidden terminals they do not change the order of magnitude. Badge-to-badge chatter over sub-GHz is limited to roughly one message per badge per minute (LoRa) or about 1/s (fast FSK, in the 869.7–870 MHz no-duty-cycle band) for a 300-badge swarm in one collision domain.
- Mesh flooding multiplies the load: computed, at Meshtastic Short Fast (≈50 ms for a 46-byte frame with 16-byte header) and 25 % target utilisation, the whole mesh carries about 1.7 original broadcasts/s if each is repeated 3 times, or 0.5/s at 10 repeats. For 300 nodes that is one message per node every 3–10 minutes. At Long Fast (≈600 ms) it is one per node every 36 minutes to 2 hours.
- Downlink-only from one base station has no such limits: it is a single transmitter, and every listener gets the packet at once.

### Gaps
- No published scalability study for a dense, single-hop, broadcast-heavy swarm (as opposed to LoRaWAN uplinks or Meshtastic chat) was found.
- The 2016/2017 LoRa studies predate the SX126x generation and Meshtastic; their exact traffic assumptions (Bor et al.) were not visible on the abstract page.

## Meshtastic, MeshCore and Reticulum: node limits, congestion at events, hop limits, latency, and use as a library

### Takeaway
Meshtastic has handled 2,000+ nodes at DEF CON 2025 only with special event firmware (Short Turbo at 500 kHz, hop limit 3, stretched telemetry intervals), and Short Turbo is not legal in the EU 10 % band. Its NodeDB keeps about 100 nodes. It is a GPL-3.0 whole firmware with a module API, not a library. MeshCore is an MIT C++ library with repeater/companion roles and flood-then-direct routing, closer to embeddable. Reticulum's C++ port (microReticulum) is experimental. None of them is designed for 20 Hz beat sync, and running one on the badge alongside the LED sync means forking it.

### Cited Findings
- Meshtastic managed flooding: nodes rebroadcast and decrement HopLimit; a node "listens a short while to see if another node has already rebroadcasted" and stays quiet if so; the contention window is small for low SNR (distant nodes rebroadcast first) and larger at higher channel utilisation; ROUTER / ROUTER_LATE always rebroadcast; a reliable broadcast is sent up to three times in total, a reliable DM up to five; next-hop routing for DMs since 2.6; for meshes with more than 40 nodes seen in 2 h, position and telemetry intervals scale up (example: 62 nodes on Long Fast stretch 1 h to about 168 min) — [Meshtastic mesh algorithm](https://meshtastic.org/docs/overview/mesh-algo/)
- Hop limit default 3, maximum 7 (3-bit header field) — [Meshtastic LoRa config](https://meshtastic.org/docs/configuration/radio/lora/)
- A simulator author notes that SNR-based flooding has no randomness, so two nodes at roughly the same distance from the sender rebroadcast at roughly the same time and collide — [Meshtastic forum, discrete-event simulator](https://meshtastic.discourse.group/t/discrete-event-simulator/5769); Meshtasticator (discrete-event simulator for Meshtastic) shows that more hops reach more nodes but the share of received packets carrying a new message falls — [GUVWAF/Meshtasticator](https://github.com/GUVWAF/Meshtasticator)
- DEF CON (blog dated 12 August 2025): attendees reported more than 2,000 nodes, "the largest known Meshtastic network to date"; firmware keeps NodeInfo for about 100 nodes at a time, which led to an eviction / spoofed-NodeInfo problem; favourites are never evicted — [Meshtastic blog, That one time at DEF CON](https://meshtastic.org/blog/that-one-time-at-defcon/)
- DEF CON 33 event firmware: "optimized event mode for dense mesh environments with tuned telemetry and GPS intervals", SHORT_TURBO preset capped at 3 hops — [Meshtastic @ DEF CON 33 announcement (Nostr repost)](https://damus.io/nevent1qqspan9u2je53kztsvwen2n7m76t8f9gxpnnl9yxu8n35lwuhter5wq9dpw4n) (secondary); Wikipedia states event firmware allows 2,000–2,500 nodes at conferences such as DEF CON (no primary source found) — [Wikipedia, Meshtastic](https://en.wikipedia.org/wiki/Meshtastic)
- A DEF CON 33 RF Village speaker: the DEF CON firmware sends shorter, faster messages "because you don't need to go very far", and is unlikely to reach anyone at home — [DEF CON 33 RF Village transcript](https://media.defcon.org/DEF%20CON%2033/DEF%20CON%2033%20villages%20and%20creators/DEF%20CON%2033%20villages%20and%20creators%20captions/DEF%20CON%2033%20-%20RF%20Village%20-%20Meshtastic%20Command%20%26%20Control.eng.txt)
- Hamvention 2024: the mesh crashed after one user's MQTT bridge flooded it — [Wikipedia, Meshtastic](https://en.wikipedia.org/wiki/Meshtastic). The Hamvention 2025 firmware blocked non-standard ports, disabled public MQTT, capped hops at 3, forced conservative telemetry/nodeinfo intervals and used Short_Turbo — [Amateur Radio Daily, May 2025](https://daily.hamweekly.com/2025/05/meshtastic-firmware-for-hamvention-2025)
- Community channel-utilisation guidance: below 25 % optimal, 25–50 % acceptable with caution, above 50 % problematic; some modules wait until utilisation drops below 25 % — [Meshtastic forum, channel utilization](https://meshtastic.discourse.group/t/understanding-and-optimizing-channel-utilization-in-meshtastic-devices/10966)
- In EU_868 the Turbo presets are not offered, because 500 kHz is not permitted in the band — [Meshtastic LoRa config](https://meshtastic.org/docs/configuration/radio/lora/)
- Meshtastic firmware: GPL-3.0; supports ESP32, nRF52, RP2040/RP2350 and Linux — [meshtastic/firmware on GitHub](https://github.com/meshtastic/firmware); built with PlatformIO, custom boards via a `variants` folder — [Meshtastic build docs](https://meshtastic.org/docs/development/firmware/build/)
- A forum user confined custom code to a Meshtastic module, but the module API relies on a cooperative OSThread scheduler; spawning a separate FreeRTOS thread for graphics stopped OSThread modules from being called — [Meshtastic forum, How to use Meshtastic as a library?](https://meshtastic.discourse.group/t/how-to-use-meshtastic-as-a-library/8294)
- The Meshtastic Arduino library is a client that talks to a Meshtastic node over Wi-Fi or serial; it is not the mesh stack — [Arduino library reference: Meshtastic](https://reference.arduino.cc/reference/en/libraries/meshtastic)
- MeshCore: "a lightweight, portable C++ library that enables multi-hop packet routing", MIT licence, PlatformIO, ships Companion / Repeater / Room Server / Simple Sensor / KISS modem examples; companion nodes do not repeat — [meshcore-dev/MeshCore](https://github.com/meshcore-dev/MeshCore)
- MeshCore routing: first message floods, each repeater appends its 1-byte ID to the path; later messages use the cached path ("~95–98 % less airtime than perpetual flooding" for repeated messages); channel messages always flood; repeaters drop floods with path_len ≥ flood_max; direct paths up to 64 hops; the radio must stay silent for at least 2× the last transmission before the next — [EastMesh wiki, MeshCore routing](https://wiki.eastmesh.au/meshcore/routing/) (community wiki)
- MeshCore v1.16.0 (6 June 2026) added separate flood caps: unscoped traffic default 64 hops ("essentially off"), adverts default 8 — [MeshCore blog, release 1.16.0](https://blog.meshcore.io/2026/06/06/release-1-16-0)
- MeshCore EU radio settings: community "EU/UK Narrow" preset 869.618 MHz, 62.5 kHz, SF8, CR 4/8 — [MeshEnvy](https://monitor.meshenvy.org/pages/about); the EastMesh wiki lists EU as 869.525 MHz, 62.5 kHz, SF7–9, CR 4/5 and 869.618 MHz as Switzerland (conflicting) — [EastMesh wiki, radio layer](https://wiki.eastmesh.au/meshcore/radio-layer/)
- No rigorous benchmark of MeshCore vs Meshtastic in dense networks exists; claims are design-based — [MeshCore vs Meshtastic comparison](https://simeononsecurity.com/articles/meshcore-vs-meshtastic-comparison-guide/)
- Reticulum: microReticulum is a work-in-progress C++ port targeting ESP32, Apache-2.0, PlatformIO; Link/Resource, Channel/Buffer and MCU memory management unfinished — [attermann/microReticulum](https://github.com/attermann/microReticulum); RTNode-HeltecV4 bridges a LoRa Reticulum network to a TCP backbone on a Heltec V4 — [jrl290/RTNode-HeltecV4](https://github.com/jrl290/RTNode-HeltecV4)

### Inferences
- Meshtastic as the swarm network: no. EU nodes share one 250 kHz channel at 10 % duty cycle, without Short Turbo; computed above, a 300-node mesh can carry one broadcast per node every few minutes, and NodeDB eviction at about 100 nodes was already a problem at DEF CON.
- Running Meshtastic on the badge and keeping the LED sync means forking GPL-3.0 firmware, writing a module under its cooperative scheduler, and coexisting with Meshtastic's own Wi-Fi/BLE use while also running ESP-NOW. Feasible for a hacker badge, but heavy, and the badge firmware would have to become GPL-3.0.
- MeshCore is the more embeddable option (MIT, C++ library, `library.json` in repo), and its repeater/companion split avoids client rebroadcast storms. It is still a messaging stack, not a time-sync protocol; using it only for base-to-badge commands adds routing and path-learning overhead that a plain RadioLib broadcast does not need.
- A useful role for Meshtastic/MeshCore: the base station (or a separate node) could post status into the camp's existing mesh, or accept commands from it, without the badges running either stack.
- Computed: a MeshCore EU-narrow frame (SF8/62.5 kHz, CR 4/8, about 30 bytes) is about 380 ms on air, 7× longer than a raw SF7/125 frame, which makes it a poor carrier for frequent effect commands.

### Gaps
- No post-event measured data (utilisation, packet loss, latency) from DEF CON 33/34 or Hamvention 2025 was found; DEF CON 34 (2026) reports were not found.
- `MAX_NUM_NODES` in the current Meshtastic firmware was not verified (forum reports range from 80 to 250; the DEF CON blog says about 100).
- End-to-end latency figures for Meshtastic or MeshCore floods were not found.
- No information found on whether CCC camps have a large existing Meshtastic/MeshCore population in 869.4–869.65 MHz.

## Range: LoRa and FSK in a crowded field at chest level vs 2.4 GHz

### Takeaway
On paper, LoRa SF7/125 at 25 mW ERP has about 30 dB more link budget than ESP-NOW at 1 Mbps and 20 dBm (computed, including the about 9 dB lower free-space loss at 868 MHz), and the base station at 500 mW gains about 44 dB. FSK at 38–250 kbps gains only about 11–16 dB. Measured body-worn LoRa reaches about 1.5 km to a base in a city and 300–600 m in forest or mountains. Body shadowing at 2.4 GHz is 5–17 dB median. A small 868 MHz badge antenna is the biggest unknown.

### Cited Findings
- SX1261/2 sensitivity (Rx Boosted): LoRa 125 kHz SF7 -124 dBm, SF12 -137 dBm; 250 kHz SF7 -121, SF12 -134; 500 kHz SF7 -117, SF12 -129; FSK 4.8 kb/s -118, 38.4 kb/s -109, 250 kb/s -104 dBm. Power-saving gain LoRa SF12/125 -133 dBm, FSK 4.8 kb/s -115 dBm — [SX1261/2 datasheet Table 3-8](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- ESP32-S3 sensitivity: 802.11b 1 Mbps -98.4 dBm, 11 Mbps -88.6, 802.11g 6 Mbps -93.2, 802.11n HT20 MCS0 -92.6 dBm; TX power 21 dBm at 802.11b — [ESP32-S3 datasheet v2.2](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf)
- ESP32 Wi-Fi long-range (LR) mode: -105 dBm at 125 kbps, works only between ESP32s (original ESP32, forum, older) — [esp32.com forum](https://esp32.com/viewtopic.php?p=15772)
- Body loss at 2.4 GHz (anechoic chamber, patch antennas, 3 m link): median 17 dB with the body 0.3 m in front of the receiver, 11 dB side, worst case up to 34 dB; at 5 m with the body halfway, 5–6 dB median — [IEEE 802.15-08-0434](https://mentor.ieee.org/802.15/dcn/08/15-08-0434-00-0006-path-loss-due-to-human-body.pdf)
- Attenuation and multipath grow with frequency, so 2.4 GHz weakens faster than 433/868/915 MHz (qualitative, 2011) — [Xu et al., PIMRC 2011](https://cse.buffalo.edu/~wenyaoxu/papers/conference/xu-pimrc2011.pdf)
- Wearable LoRa with a textile front-to-back diversity antenna: about 1.5 km off-body (body to base station) in an urban setting at walking/cycling speed; diversity added up to 5.5 dB (IEEE TAP 2021) — [researchportal.be](https://researchportal.be/nl/node/7374001)
- Body-worn LoRa to a near-ground UAV at 868 MHz in a Mediterranean forest: about 600 m full range, severe Nakagami-m fading (2023) — [arXiv 2303.12754](https://arxiv.org/pdf/2303.12754)
- Body-worn LoRa in mountains: 300 m at ≥50 % packet reception (2020) — [unibz](https://bia.unibz.it/esploro/outputs/conferencePresentation/Radio-wave-propagation-of-LoRa-systems/991005835651301241)
- ESPHome user with Heltec V3 boards: best receiver RSSI -111 dBm, SNR 8.25 dB at range (anecdote) — [Home Assistant forum](https://community.home-assistant.io/t/sx126x-heltec-lora/944369)
- 868 MHz chip antenna (Johanson 0868AT43A0020, corner mount): Rev 2.0 datasheet peak -1.0 dBi, average -4.0 dBi on Johanson's evaluation board — [Johanson datasheet](https://www.johansontechnology.com/docs/4384/Antenna-0868AT43A0020001E-2.0.pdf); an earlier revision gave -2.5 dBi peak, -6.0 dBi average, 26 % average efficiency (from search summary)

### Inferences
- Computed link budgets (ERP converted to EIRP with +2.15 dB; compared against ESP-NOW at 1 Mbps; "freq" adds 20·log10(2440/868) ≈ 9.0 dB of lower free-space loss at 868 MHz, assuming equal antenna gain):

| Link | Budget | vs ESP-NOW 20 dBm (118.4 dB) incl. freq | vs badge ESP-NOW 13 dBm (111.4 dB) |
|---|---|---|---|
| LoRa SF7/125, 25 mW ERP | 140.2 dB | +30.7 dB | +37.7 dB |
| LoRa SF7/250, 25 mW ERP | 137.2 dB | +27.7 dB | +34.7 dB |
| LoRa SF7/125, 5 mW ERP (869.7–870, no duty cycle) | 133.2 dB | +23.7 dB | +30.7 dB |
| LoRa SF7/125, base 500 mW ERP (869.4–869.65) | 153.2 dB | +43.7 dB | +50.7 dB |
| FSK 38.4 kbps, 25 mW ERP | 125.2 dB | +15.7 dB | +22.7 dB |
| FSK 250 kbps, 25 mW ERP | 120.2 dB | +10.7 dB | +17.7 dB |

- With a ground-level path-loss exponent of 3–4, +30 dB is roughly 6–11× the range of ESP-NOW and +44 dB roughly 12–29× (computed). Badges today reach the base at -85 to -95 dBm against a -98.4 dBm sensitivity (assuming ESP-NOW runs at the 802.11b 1 Mbps rate; not verified here), a margin of only about 3–13 dB; a LoRa downlink would have about 40–55 dB margin at the same spot, enough to cover a site several hundred metres across from one mast, with crowds in between.
- The badge antenna can eat a large part of this: a quarter wave at 868 MHz is about 8.6 cm, much larger than the 30 × 34 mm board; chip-antenna figures (-4 to -6 dBi average) are for evaluation boards, and a small ground plane probably costs more. A wire antenna along the lanyard is an option.
- Fast FSK gives only a modest gain over Wi-Fi 1 Mbps; LoRa's chirp spread spectrum, not the frequency alone, delivers most of the range advantage.
- Sub-GHz RSSI may be a smoother distance proxy for proximity effects (less body shadowing), but the long range means many more badges are "in view", which may make proximity effects less local.

### Gaps
- No measured 868 MHz body-to-body range in a dense crowd was found.
- No measured efficiency of an 868 MHz antenna on a ground plane as small as 30 × 34 mm was found.
- No direct 868 MHz vs 2.4 GHz body-shadowing comparison was found.

## Power: SX1262 RX/TX current, duty-cycled RX and CAD, and Meshtastic battery life on nRF52840 vs ESP32-S3

### Takeaway
The SX1262 receives at 4.6–5.3 mA and transmits at 45 mA at +14 dBm (118 mA at +22 dBm). Its built-in RX duty cycle (sniff) mode can cut average listen current to about 1–2 mA (computed) at the cost of longer sender preambles. Real boards are dominated by everything else: an ESP32-S3 with Wi-Fi off still draws about 13–42 mA at 40–160 MHz, while nRF52840 Meshtastic nodes idle at about 2–10 mA. For the badge, a LoRa receive-only link plus Wi-Fi off would save roughly 40–65 mA of the current about 90 mA radio budget (computed).

### Cited Findings
- SX1261/2 current: sleep cold start 160 nA, warm start 600 nA (1.2 µA with RC64k); STDBY_RC 0.6 mA; STDBY_XOSC 0.8 mA; RX (DC-DC) FSK 4.8 kb/s 4.2 mA, LoRa 125 kHz 4.6 mA; Rx Boosted 4.8 / 5.3 mA; LDO mode 8.0–10.1 mA — [SX1261/2 datasheet Table 3-5](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- SX1262 TX at 868/915 MHz: +22 dBm 118 mA; +20 dBm 84 mA (optimal settings); +17 dBm 58 mA (optimal); +14 dBm 45 mA (optimal). SX1261 at +14 dBm 25.5 mA, +10 dBm 15–18 mA (VBAT 3.3 V) — [SX1261/2 datasheet Table 3-6](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- SetRxDutyCycle ("sniff" / listen mode): the chip alternates RX for `rxPeriod` and SLEEP for `sleepPeriod` (units of 15.625 µs), with about 500 µs to save context and restart on each side; on preamble detection it stays in RX for 2·rxPeriod + sleepPeriod — [SX1261/2 datasheet §13.1.7](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)
- RadioLib `startReceiveDutyCycleAuto(senderPreambleLength, minSymbols)` chooses the RX/sleep periods so packets are not missed; needs 8 preamble symbols for SF7–12 (12 for SF5–6); falls back to continuous RX if the sender preamble is shorter than 2·minSymbols + 1. `startChannelScan()` / `scanChannel()` do CAD with AN1200.48 defaults — [RadioLib SX126x reference](https://jgromes.github.io/RadioLib/class_s_x126x.html)
- MeshCore low-power fork: Heltec V3 repeater idle 7.8 mA without RX duty cycle, 4.9 mA with it (about 9.1 vs 14.5 days on 2000 mAh); RX duty cycle only at SF5–SF8; a later fix (v1.17_1004) addressed long messages often lost with RX duty cycle on; Heltec V4.3 companion with GPS duty cycling about 23 mA — [dt267/MeshCore-Low-Power-Firmware-For-Heltec-V3-V4](https://github.com/dt267/MeshCore-Low-Power-Firmware-For-Heltec-V3-V4)
- ESP32-S3 with Wi-Fi clock-gated (modem-sleep), CPU idle (WAITI): 13.2 mA at 40 MHz, 22.0 mA at 80 MHz, 27.6 mA at 160 MHz, 32.9 mA at 240 MHz (all peripheral clocks off; 18.8 / 36.1 / 42.3 / 47.6 mA with all on); deep sleep 7 µA; Wi-Fi RX 88–91 mA; TX 802.11b at 21 dBm 340 mA peak — [ESP32-S3 datasheet v2.2, Tables 5-7, 5-9](https://documentation.espressif.com/esp32-s3_datasheet_en.pdf)
- Heltec V4 test (20 January 2026, Meshtastic): deep standby floor about 12 mA; transmit at 27 dBm peaks near 1 A for about 1 s; average about 95 mA with Bluetooth on; 46 h 40 min on 2 × 3000 mAh 18650 in parallel — [Heltec wiki, V4 test result](https://wiki.heltec.org/news/heltec-v4-test-result/heltec-v4-test-result)
- Heltec T114 (nRF52840): about 9 mA active with GPS and TFT off, 20 mA TFT on, 51 mA GPS + TFT; deep sleep about 11 µA; Meshtastic low-power mode about 23 µA — [Heltec T114 product page](https://heltec.org/project/mesh-node-t114/)
- RAK4631 (nRF52840 + SX1262): TX LoRa 20 dBm about 125 mA (garbled table), 17 dBm 92 mA; RX LoRa 17 mA (listed as "@37.5 kbps"); sleep 2.0 µA — [RAK4631 datasheet](https://docs.rakwireless.com/product-categories/wisblock/rak4631/datasheet/)
- Forum anecdotes: a Heltec V3 draws about 100 mA as a Meshtastic Client and about 10 mA idle as Router; a RAK4631 without GPS 2–6 mA when not sending, RAK4630 about 5–10 mA in router mode vs about 100 mA for a T-Beam — [Meshtastic forum, Heltec V3 battery draining](https://meshtastic.discourse.group/t/heltec-v3-2-2-17dbac2b1-battery-drainin-rapidly/9555), [Meshtastic forum, router mode energy](https://meshtastic.discourse.group/t/router-mode-consumes-large-amount-of-energy/5433?page=2) (search snippets; exact thread attribution not verified)
- XIAO ESP32S3: about 14 µA deep sleep (Seeed figure) — [CNX Software](https://www.cnx-software.com/2023/03/22/xiao-esp32s3-tiny-esp32-s3-wifi-4-and-ble-5-0-module-for-iot-ai-robotics/)
- ESPHome `sx126x.set_mode_sleep`: warm sleep about 600 µA vs cold sleep about 0.6 µA (as stated in ESPHome docs; note that the datasheet says 600 nA for warm sleep) — [ESPHome SX126x component](https://esphome.io/components/sx126x/); compare [SX1261/2 datasheet](https://cdn.sparkfun.com/assets/6/b/5/1/4/SX1262_datasheet.pdf)

### Inferences
- Computed RX duty-cycle averages (SX1262 Rx Boosted 5.3 mA, 8-symbol detection window + 0.5 ms wake, sleep = preamble − 17 symbols): SF7/125 with a 32-symbol preamble ≈ 1.9 mA average; with 64 symbols ≈ 0.8 mA (the sender pays 66 ms of preamble, more than doubling a 57 ms packet); SF7/250 with 64 symbols ≈ 0.85 mA; SF9/125 with 32 symbols ≈ 1.9 mA. For a base-station-only transmitter with 10 % duty cycle, a long preamble is affordable.
- Badge power: today radio ≈ 90 mA (Wi-Fi RX with CPU). A LoRa-only receiver badge would draw roughly ESP32-S3 modem-sleep at 80–160 MHz (22–42 mA) + SX1262 (0.8–5.3 mA) ≈ 25–48 mA, saving about 40–65 mA. If the badge still needs 2.4 GHz for RSSI proximity, a 10–20 % Wi-Fi duty cycle adds about 9–18 mA. On the 1000 mAh cell with the LED load of 35–271 mA, this is a meaningful runtime gain, but the LEDs remain the dominant load in a crowd.
- TX at +14 dBm (45 mA) for 57 ms once every 6 s is about 0.4 mA average; badge LoRa transmissions are not the power problem, duty cycle and capacity are.
- nRF52840 boards (T114, RAK4631, Wio Tracker L1) idle an order of magnitude lower than ESP32-S3 boards under Meshtastic, but the badge needs the ESP32-S3 for ESP-NOW and FastLED, so this matters only for base or relay nodes.

### Gaps
- No independent, like-for-like current measurement of Heltec V3/V4, T114, RAK4631, XIAO kit and T3-S3 under the same firmware was found.
- No measurement of an SX1262 + ESP32-S3 node running FastLED was found.

## Hardware: LoRa + ESP32-S3 / nRF52840 boards (price, size, charging, current, RadioLib/Arduino support)

### Takeaway
Cheap, Arduino/PlatformIO-friendly ESP32-S3 + SX1262 boards exist from about $10 (Seeed XIAO ESP32S3 + Wio-SX1262 kit) to $20–28 (Heltec V3/V4, Wireless Stick Lite V3, RAK3312) and $55–60 (T-Beam Supreme with GPS). nRF52840 + SX1262 boards (Heltec T114, RAK4631, Wio Tracker L1) idle much lower. Bare SX1262 modules for the custom badge PCB cost about $3.90–6.60. RadioLib covers SX126x, SX127x, SX128x, LR11x0 (including LR1121) and LR2021 on ESP32 and nRF52, under Arduino, PlatformIO and ESP-IDF.

### Cited Findings
- RadioLib supports SX1261/2/8, SX127x, SX1280/1/2, LR1110/1120/1121, LR2021, LLCC68 and others; platforms include Espressif ESP32 and Adafruit nRF52; listed on the PlatformIO registry and the Espressif component registry; LoRaWAN on SX126x, LR11x0, SX128x — [jgromes/RadioLib](https://github.com/jgromes/RadioLib)
- Heltec WiFi LoRa 32 V4: ESP32-S3R2 or S3R8, SX1262, 28 ± 1 dBm (high-power version, GC1109 PA) or 22 dBm; $17.90–27.50; 51.7 × 25.4 × 10.7 mm; LiPo connector plus 4.7–6 V solar input; GNSS connector; OLED optional; Arduino, PlatformIO, ESP-IDF; Meshtastic ≥2.7.20 (R8 ≥2.7.25), MeshCore ≥1.15 — [Heltec V4 page](https://heltec.org/project/wifi-lora-32-v4/); measured 25.6 dBm at a 27 dBm setting — [Heltec V4 test](https://wiki.heltec.org/news/heltec-v4-test-result/heltec-v4-test-result)
- Heltec Wireless Stick Lite V3 (ESP32-S3 + SX1262, no display): €19.50 incl. VAT (868 MHz) — [Tinytronics](https://www.tinytronics.nl/nl/development-boards/microcontroller-boards/met-lora/heltec-wireless-stick-lite-v3-lora-868mhz-esp32-s3-sx1262); $19.99–24.97 at other resellers — [Rokland](https://store.rokland.com/en-de/collections/vendors/products/heltec-wireless-stick-litev3-902-928-mhz)
- Heltec Mesh Node T114 (nRF52840 + SX1262): 21 ± 1 dBm; $17.90–33.70; 50.80 × 22.86 mm, 35 g; LiPo charging, solar input; optional 1.14" TFT and L76K GNSS; Arduino and PlatformIO; Meshtastic and MeshCore — [Heltec T114](https://heltec.org/project/mesh-node-t114/)
- Seeed XIAO ESP32S3 + Wio-SX1262 kit: $9.90 (CNX) / $10.90 excl. VAT (Seeed datasheet, per search) / £10.50 incl. VAT; 21 × 17.8 mm; up to +22 dBm; pre-flashed Meshtastic; 100 mA battery charging; Wio-SX1262 module alone $4.29 — [CNX Software](https://www.cnx-software.com/?p=139035), [The Pi Hut](https://thepihut.com/products/xiao-esp32s3-wio-sx1262-kit-for-meshtastic-lora)
- LilyGO T3-S3 (ESP32-S3 + SX1262, 868 MHz): €30.75 incl. VAT — [Passion Radio](https://www.passion-radio.com/tracker/t3s3-868-3042.html); OLED versions $34.68–49.90 at OpenELAB (search snippet)
- LilyGO T3-S3 LR1121: ESP32-S3FH4R2; LR1121 covering 400–520, 830–945 and 2400–2500 MHz; 66 × 27 × 15 mm; 500 mA charging; Arduino and PlatformIO examples with RadioLib; price not listed — [LilyGO wiki](https://wiki.lilygo.cc/products/t3-series/t3-s3-lr1121/)
- Waveshare ESP32-S3-LR1121: 2.4 GHz TX -18 to 13 dBm, sub-GHz -9 to 22 dBm — [Waveshare](https://www.waveshare.com/esp32-s3-lr1121.htm)
- LilyGO T-Beam Supreme (ESP32-S3 + SX1262 + GNSS): $59.97 / €52.95–53.95 — [Rokland](https://store.rokland.com/products/lilygo-t-beam-supreme-esp32-s3-lora-development-board-sx1262-915mhz-gps-l76k-or-u-blox)
- RAK4631 (nRF52840 + SX1262, WisBlock core): 20 × 30 mm; up to 22 dBm; Arduino BSP; sleep 2 µA — [RAK4631 datasheet](https://docs.rakwireless.com/product-categories/wisblock/rak4631/datasheet/)
- RAK3312 (ESP32-S3 + SX1262, WisBlock core): listed at $15.00 — [RAK store](https://store.rakwireless.com/products/wisblock-core-module-rak3312-lora-wifi-ble); WisMesh RAK3312 starter kit $33.97 / €29.95 — [Rokland](https://store.rokland.com/products/wismesh-rak3312-starter-kit-with-meshtastic-firmware)
- Seeed Wio Tracker L1 (nRF52840 + SX1262 + GNSS): Lite £26.80 incl. VAT — [The Pi Hut](https://thepihut.com/products/wio-tracker-l1-lite); Pro $39.90 at launch — [CNX Software, May 2025](https://www.cnx-software.com/2025/05/31/wio-tracker-l1-pro-is-a-battery-powered-ready-to-use-meshtastic-lora-node/)
- Elecrow ThinkNode M1 (nRF52840 + SX1262, 1.54" e-paper): €56.85–64.85 / $66.99 — [OpenELAB](https://openelab.io/collections/elecrow-thinknode)
- Bare modules for a custom PCB: Heltec HT-RA62 (SX1262) $3.90 — [Heltec HT-RA62](https://heltec.org/product/ht-ra62/); Ebyte E22-900M22S (SX1262, TCXO, 22 dBm) $6.60 at qty 1, $4.63 at 100+ — [LCSC C411293](https://www.lcsc.com/product-image/C411293.html); Wio-SX1262 £4.80 — [The Pi Hut](https://thepihut.com/products/wio-sx1262-for-xiao)

### Inferences
- For a base station or fixed relays: Heltec V4 (28 dBm PA; note that 27 dBm ERP is the legal maximum in 869.4–869.65 MHz, including antenna gain) or a RAK3312 / Wireless Stick Lite V3.
- For prototyping a LoRa-receiving badge: the XIAO ESP32S3 + Wio-SX1262 kit (about $10, 21 × 17.8 mm) is the cheapest and closest to the badge's ESP32-S3.
- For the custom badge PCB: an HT-RA62 or E22-900M22S module (about $4–7) plus an 868 MHz antenna and matching would add roughly $5–8 to an $8.91 BOM (+55–90 %), and needs board area for an antenna that the 30 × 34 mm layout does not have today.
- The ESP32-S3FH4R2 in the badge has the same memory as the LilyGO T3-S3, which suggests Meshtastic-class firmware could fit, but this is not verified.

### Gaps
- Heltec WiFi LoRa 32 V3 current price and LilyGO T3-S3 LR1121 price were not found.
- Independent current measurements for most boards (beyond the vendor figures above) were not found.

## 2.4 GHz LoRa (SX1280 / LR1121) as a middle ground

### Takeaway
2.4 GHz LoRa has no duty-cycle limit at ≤10 dBm (Meshtastic LORA_24: 100 % duty cycle, 10 dBm) and short packets (computed: about 9 ms for 20 bytes at SF7/812.5 kHz, about 1.5 ms at SF5/1625 kHz). It gains link budget over Wi-Fi through spreading, but shares 2.4 GHz body absorption and the band with the badges' own ESP-NOW. Above 10 dBm EIRP, EN 300 328 requires either adaptivity (LBT/DAA) or medium utilisation ≤10 %.

### Cited Findings
- SX1280: RX current 5.5 mA, sensitivity -132 dBm at SF12/203 kHz, TX +12.5 dBm, SF5–12, bandwidth 200–1600 kHz — [Semtech LoRa Connect product table](https://www.semtech.com/lora-connect); a Semtech 2.4 GHz gateway reference design cites -129 dBm at SF12/812.5 kHz (search snippet) — [Semtech SX1280 gateway reference](https://www.semtech.com/products/wireless-rf/lora-core/sx1280zxxxxgw1)
- Meshtastic LORA_24 region: 2400.0–2483.5 MHz, 100 % duty cycle, 10 dBm — [Meshtastic LoRa config](https://meshtastic.org/docs/settings/config/lora)
- EN 300 328: non-adaptive equipment above 10 dBm EIRP must keep medium utilisation ≤10 %; adaptive (LBT/DAA) equipment is exempt; maximum 20 dBm EIRP. Sources disagree on whether exactly 10 dBm is exempt — [Intertek, EN 300 328 medium utilization](https://www.intertek.com/ict/etsi-en-300-328/medium-utilization)
- In the UK there are no duty-cycle limits for a 2.4 GHz LoRa device at 10 mW (forum, older) — [TTN forum, 2.4 GHz LoRa](https://www.thethingsnetwork.org/forum/t/2-4-ghz-lora/6045)
- Range: SX1280 simulation (Sensors 2020) gives 443–867 m outdoor urban and 74–107 m indoor office (two published versions conflict) — [Janssen et al., Sensors 2020](https://www.mdpi.com/1424-8220/20/16/4366); NiceRF LoRa1280 field test at 10 dBm: 1.7 km on a highway (vendor) — [NiceRF](https://www.nicerf.com/news/lora-module-lora1280-field-measurement.html)
- LR1121 2.4 GHz TX power -18 to 13 dBm (vs -9 to 22 dBm sub-GHz) on the Waveshare ESP32-S3-LR1121 — [Waveshare](https://www.waveshare.com/esp32-s3-lr1121.htm)
- RadioLib supports SX128x and LR11x0 — [RadioLib](https://github.com/jgromes/RadioLib)

### Inferences
- Computed 20-byte airtimes with the sub-GHz formula (approximate for SX1280): SF5/1625 kHz 1.5 ms, SF7/812.5 kHz 9.3 ms, SF7/406 kHz 18.7 ms, SF9/812.5 kHz 31 ms. 300 badges at 1 packet/s at SF7/812.5 kHz give G ≈ 2.8 (pure ALOHA: almost nothing gets through); at SF5/1625 kHz G ≈ 0.45 (about 41 % success). Like sub-GHz LoRa, it does not carry 20 Hz per badge from hundreds of badges in one collision domain.
- 2.4 GHz LoRa is a reasonable long-range backbone that needs no duty-cycle bookkeeping and works worldwide, but at 10 dBm its budget advantage over the badge's own ESP-NOW (13 dBm) comes from spreading gain alone, with no help from frequency or bodies.
- An LR1121 gives both 868 MHz and 2.4 GHz LoRa from one chip (for example a sub-GHz backbone plus 2.4 GHz LoRa locally), but it adds a second 2.4 GHz transmitter next to the ESP32-S3's Wi-Fi.

### Gaps
- No measured SX1280/LR1121 range at chest level in a crowd and no measured sensitivity at SF5–SF7 with 800–1600 kHz were found.
- No Meshtastic 2.4 GHz field reports were found.

## ESPHome support for SX126x/SX127x and custom packets; Meshtastic–ESPHome bridges

### Takeaway
ESPHome has native `sx126x` and `sx127x` components since 2025.7.0 (16 July 2025). It supports LoRa and FSK, raw `send_packet` / `on_packet` (with RSSI and SNR), and `packet_transport` over LoRa for sharing sensor states between nodes. There is no native Meshtastic component; bridging means a UART stream server plus a host-side protobuf client. LR11x0 / SX128x are not supported in ESPHome as far as I found.

### Cited Findings
- ESPHome 2025.7.0 (16 July 2025) added "SX126x & SX127x LoRa modules" — [ESPHome 2025.7.0 changelog](https://esphome.io/changelog/2025.7.0/), [ESPHome 2025.7 blog](https://esphome.io/blog/2025/07/16/esphome-2025-7/)
- `sx126x` component: `hw_version` sx1261 / sx1262 / sx1268 / llcc68; 150–960 MHz; `modulation: LORA` or `FSK`; `pa_power` -3 to 22 dBm (15 for sx1261); LoRa bandwidth 7.8–500 kHz, SF 6–12 (default 7), CR 4/5–4/8, `payload_length` up to 255 (implicit header when > 0), preamble ≥6 (default 8), `sync_value` (default `[0x14, 0x24]`, `[0x34, 0x44]` reserved for LoRaWAN); FSK bandwidth 4.8–467 kHz, `bitrate`, `deviation` 0–100 kHz, shaping, whitening, CRC options; `on_packet` trigger with `x` (std::vector<uint8_t>), `rssi`, and `snr` in LoRa mode; actions `send_packet` (templatable data), `set_mode_tx/rx/standby/sleep`, `run_image_cal`; parameters changeable at runtime via lambdas then `configure`. The page does not mention duty cycle or EU regulations — [ESPHome SX126x](https://esphome.io/components/sx126x/)
- `packet_transport`: shares sensor and binary-sensor states between ESPHome nodes, providers and consumers; transports ESP-NOW, SX126x, SX127x, UART, UDP; `update_interval` default 15 s; optional XXTEA encryption with a shared key, 64-bit rolling code, ping-pong nonce; raw custom payloads are not documented for packet_transport itself — [ESPHome Packet Transport](https://esphome.io/components/packet_transport/), [SX126x packet transport platform](https://esphome.io/components/packet_transport/sx126x/)
- A user ran ESPHome sx126x on Heltec LoRa V3 boards with `on_packet` logging RSSI/SNR — [Home Assistant forum](https://community.home-assistant.io/t/sx126x-heltec-lora/944369)
- No maintained ESPHome–Meshtastic component was found; the nearest building block is an ESPHome UART-to-TCP stream server that passes raw bytes (no protobuf parsing) — [tube0013/esphome-stream-server](https://github.com/tube0013/esphome-stream-server)

### Inferences
- ESPHome can do the backbone role with no C++: a base node with `sx126x.send_packet` from a lambda, and badges with `on_packet` lambdas that parse a few bytes. The duty-cycle limit must be enforced in the YAML/lambda, since the component does not.
- ESP-NOW is also a `packet_transport` transport in ESPHome, so a hybrid badge (ESP-NOW + SX126x) is configurable in ESPHome, but 20 Hz beat sync and FastLED effects would still be custom lambdas or an external component.

### Gaps
- The ESPHome `sx127x` component page was not opened; its option list is assumed similar but unverified.
- No ESPHome support for LR1121 or SX1280 was found (absence not proven).

## Hybrid design: 2.4 GHz for local beat sync and RSSI, sub-GHz for site-wide commands — sensible, and what it costs per badge

### Takeaway
The hybrid is sensible if sub-GHz is used one-way: the base station (plus 1–3 relays if needed) broadcasts effect commands and a global phase reference on 869.4–869.65 MHz at up to 500 mW ERP / 10 %, and badges only receive. There are two ways to deliver it. Either every badge gets an SX1262 (about $4–7 module plus antenna, roughly +55–90 % on the $8.91 BOM), or the badges stay unchanged and a handful of fixed LoRa-to-ESP-NOW relay nodes ($10–28 each) re-broadcast commands locally on 2.4 GHz.

### Cited Findings
- Base station at 869.4–869.65 MHz: 500 mW ERP, ≤10 % duty cycle — [ETSI EN 300 220-2 V3.2.1](https://www.etsi.org/deliver/etsi_en/300200_300299/30022002/03.02.01_60/en_30022002v030201p.pdf)
- Heltec V4 delivers about 25.6 dBm measured at a 27 dBm setting, $17.90–27.50 — [Heltec V4 test](https://wiki.heltec.org/news/heltec-v4-test-result/heltec-v4-test-result), [Heltec V4](https://heltec.org/project/wifi-lora-32-v4/)
- SX1262 module prices $3.90 (HT-RA62) to $4.63–6.60 (E22-900M22S) — [Heltec](https://heltec.org/product/ht-ra62/), [LCSC](https://www.lcsc.com/product-image/C411293.html)
- Current badge BOM $8.91 per board at 100 units, 30 × 34 mm, 2.4 GHz corner chip antenna — [herz_badge/BOM.md, commit 253e135](/Users/foz/src/Herz_Schwarm_CCC_V/herz_badge/BOM.md)
- Base station hardware today: Spotpear ESP32-S3R8 with W5500 Ethernet, Wi-Fi used only for ESP-NOW — [todo.md](/Users/foz/src/Herz_Schwarm_CCC_V/todo.md)
- ESPHome `packet_transport` supports both ESP-NOW and SX126x transports — [ESPHome Packet Transport](https://esphome.io/components/packet_transport/)

### Inferences
- Option A, LoRa in every badge (receive-only): each badge gets camp-wide commands and a common beat clock directly. Computed: Wi-Fi on only for short proximity/sync windows saves roughly 40–65 mA, minus whatever the 2.4 GHz windows cost. Costs: about $5–8 per badge (module, 868 MHz antenna, matching), PCB area for the antenna, and firmware for RadioLib RX duty cycle. Range margin of about 40–55 dB over today's -85 to -95 dBm base link, minus antenna losses.
- Option B, LoRa only at base + relays: 2–6 relays (Heltec V4 / Wireless Stick Lite V3 / RAK3312, about $10–28 each, powered by USB packs or mains) on poles across the field receive LoRa from the base and re-broadcast on ESP-NOW channel 13 at 20–21 dBm. No badge hardware change, no badge power saving. This mostly solves "badges reach the base only at -85 to -95 dBm". The relays could just as well be fed by Ethernet/Wi-Fi/MQTT; LoRa's advantage is no cabling over hundreds of metres.
- Option C, LoRa between badges (two-way): not recommended. Computed: at most about one LoRa packet per badge per minute for a 300-badge swarm, or about one fast-FSK packet per second in the 869.7–870 MHz 5 mW band, with heavy collisions.
- Message design for the backbone: a fixed-length (implicit header) 8–16-byte command and phase packet at SF7/125 is about 40–50 ms (computed); at a 10 % budget that is one command every 0.5 s on average, and bursts are fine. Add a sequence number and repeat each command 2–3 times instead of ACKs.
- Coexistence: Meshtastic/MeshCore users at the camp sit in the same 250 kHz band; a badge backbone transmitting at 10 % could interfere with them and vice versa. The 865–868 MHz 500 mW networked channels (10 % for access points), if allowed in Germany, would avoid this.
- Sub-GHz does not help the RSSI proximity effect; keep that on 2.4 GHz (ESP-NOW, or BLE advertising, which an ESP32-S3 can do at lower average current than an always-on Wi-Fi receiver, not quantified here).

### Gaps
- No cost data for an 868 MHz antenna solution on a 30 × 34 mm badge (chip antenna plus matching, or a lanyard wire) and its measured efficiency.
- Not verified whether BNetzA Vfg. 91/2025 includes the 865–868 MHz 500 mW network channels.
- Whether other camp radio users (Meshtastic, MeshCore, LoRaWAN gateways, camp infrastructure) occupy 869.4–869.65 MHz at a CCC camp is unknown.
