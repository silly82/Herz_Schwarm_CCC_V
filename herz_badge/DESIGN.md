# Herz-Schwarm Badge: design notes

Status (2026-10-17): reference reverse-engineered and redrawn (`boards/reference/`, netlist identical to the
vendor's). Battery badge (`boards/badge/`): datasheets summarised, power path simulated (`sim/`), parts revised
after both (D12–D16), placed on 30 × 34 mm, 4 layers, not routed; order files for a JLC quote. Battery safety
reviewed 2026-10-18 (section 5): rules for cells and mounting (D18, D19), and a fuse, an NTC and a connector move
proposed for routing. Next: the quote, a real badge measured (section 9), the firmware changes of D17, the section 5
proposals decided, then routing.

## 1. Requirements

- **R1 Same badge.** Runs the badge firmware (1.4.0) unchanged: 8×8 RGB matrix on GPIO14 in the same chain order,
  BOOT button on GPIO0, ESP32-S3 with ESP-NOW, USB-C for flashing.
- **R2 Battery.** Runs from one LiPo cell, charges from USB-C, and keeps running while it charges.
- **R3 Size.** About the reference's 25 × 25 mm, with the cell behind the board.
- **R4 Off switch.** Cuts the load completely for storage and transport; charging still works when off.
- **R5 Battery voltage.** Firmware can read it, for a low-battery warning and a brightness cap on battery.
- **R6 Made at JLC.** Assembled at JLC from stocked parts; Basic parts where the function allows.
- **R7 Safe at a camp.** No single fault starts a fire. That covers a short on the board, a bad or reversed cell,
  charging in heat or cold, and a crushed cell. Cells, labels and disposal follow EU and Swiss rules (section 5).
- Wanted: keep the IMU (tilt effects, wake on motion later). Not needed: the 2×10 header (no firmware uses it).

## 2. The reference board

Waveshare ESP32-S3-Matrix (SKU 27119), sold on AliExpress by SpotPear as "ESP32-S3 Matrix 8x8 RGB-LED-WiFi
Bluetooth With QST Attitude Gyro Sensor QMI8658C". Sources:

- Schematic: <https://files.waveshare.com/wiki/ESP32-S3-Matrix/ESP32-S3-Matrix-Sch.pdf> (Altium, 2024-03-25). Its
  bookmark tree carries the full netlist; `scripts/vendor_netlist.py` reads it into `design/reference-netlist.json`
  (109 parts, 133 nets).
- Redraw: `scripts/sch_reference.py` builds `boards/reference/` from that JSON with the vendor's designators;
  `scripts/check_reference.py` compares the KiCad netlist pin for pin (2026-10-17: 0 differences). ERC shows two
  warnings, both the IMU's SA0 and SDx pins tied to rails as the vendor did.
- Dimensions and photos: <https://docs.waveshare.com/ESP32-S3-Matrix>.

### 2.1 Blocks

| Block | Parts | What it does |
| --- | --- | --- |
| USB-C | J1, R1, R2, C1 | 16-pin receptacle; CC1/CC2 5.1 kΩ to GND (5 V sink); D+/D− to GPIO20/19 through 22 Ω (R9/R7); SBU open; no ESD protection |
| 5 V rail | D1 | VBUS through a B5819WS Schottky to VCC_5V. The header's 5V pin is on VCC_5V, so the board can be fed from the header and the diode keeps that off USB |
| 3V3 | U49, C2–C4 | ME6217C33M5G LDO (800 mA, SOT-23-5), EN tied to VIN; 100 nF + 10 µF in, 10 µF out |
| MCU | U66, Y1, L1, C8, C12, IND1, C9–C11, C13–C16 | ESP32-S3FH4R2, bare QFN-56 with 4 MB flash and 2 MB PSRAM inside; 40 MHz crystal with 10 pF caps and the 24 nH series inductor on XTAL_P that Espressif recommends; VDD3P3 (pins 2, 3) through a 2 nH inductor with 100 nF |
| RF | C7, R5, C6, J2 | LNA_IN → shunt C7 (not fitted) → series R5 = 0.5 pF (a capacitor, despite the R) → shunt C6 (not fitted) → CrossAir CA-C03 chip antenna, 5.2 × 2.0 mm, on the back at the bottom edge |
| Buttons | Key1, R8, Key2, R10 | RESET on CHIP_PU with a 10 kΩ pull-up; BOOT on GPIO0 with a 10 kΩ pull-up |
| IMU | U67, C17, C18 | QMI8658C on I²C: SDA GPIO11, SCL GPIO12, INT1 GPIO10, INT2 GPIO13; SA0 to GND, CS to 3V3 (I²C mode), aux SDx/SCx to 3V3; no I²C pull-ups |
| LED data | Q1, R3, R4, C5 | GPIO14 → DMG1012T level shifter (gate on 3V3, source on GPIO14 with 2.2 kΩ to 3V3, drain on LED_DIN with 4.7 kΩ to 5 V) |
| LED matrix | U1–U48, U50–U65 | 64 WS2812B in an 0807 package on VCC_5V; no decoupling at the LEDs (only C3/C4 at the LDO and C5 at Q1). The last DOUT goes to pad TP1 next to TP2 (5 V) and TP3 (GND), for chaining another matrix |
| Header | P1, R6 | 2 × 10 at 2.54 mm, rows 22.86 mm apart. Left, top to bottom: 5V, GND, 3V3, IO7…IO1. Right, bottom to top: RX, TX (through 499 Ω), IO40…IO33 |

LED chain (the order the firmware addresses): U8, U7 … U1, then U16 … U9, U24 … U17, and so on to U65 … U58; each
schematic row is eight LEDs and ends in DOUT_1 … DOUT_7. Where index 0 sits, and whether the rows run the same way
(row-major) or alternate (serpentine), is not in the schematic. The firmware treats `i / 8` as the row; its heart is
mirror-symmetric in every row, so it would look right either way. Measure it (section 9) before placing the clone's
LEDs.

### 2.2 GPIO use

| GPIO | Reference board | Badge firmware 1.4.0 |
| --- | --- | --- |
| 0 | BOOT button (strapping) | Morse button |
| 1–7, 33–40, 43/44 (TX/RX) | header | unused |
| 10, 11, 12, 13 | IMU INT1, SDA, SCL, INT2 | unused |
| 14 | LED data through Q1 | `LED_PIN` |
| 19, 20 | USB D−, D+ | USB CDC for flashing and debug |
| 8, 9, 15–18, 21, 41, 42, 45–48 | not connected | |

### 2.3 Physical

25.00 × 25.00 mm, 1.0 mm corner radius. Header pads 1.07 mm in from the edges at 2.54 mm pitch, rows 22.86 mm apart.
USB-C at the top edge, overhanging it. LEDs alone on the front; ESP32-S3, IMU, USB-C, both buttons, crystal, LDO and
antenna on the back (photos on the Waveshare page). The LED pitch is not dimensioned; the product photo suggests
about 2.6–2.8 mm.

### 2.4 What the reference teaches

1. **CHIP_PU has no capacitor.** Espressif's schematic checklist recommends an RC delay of 10 kΩ and 1 µF on
   CHIP_PU, so the chip leaves reset after its supply is stable; the board has only the pull-up. A nearly empty cell
   or a switch FET with a slow gate makes the supply ramp less tidy than USB, so the clone adds the 1 µF.
2. **VDD_SPI (pin 29) is not decoupled.** The checklist asks for 0.1 µF and 1 µF close to the pin. The clone adds them.
3. **No I²C pull-ups** for the IMU; it relies on the ESP32's internal ones (tens of kΩ). Add 4.7–10 kΩ for 400 kHz.
4. **No decoupling at the LEDs.** 64 LEDs switching at once share C3/C4 at the far end. The firmware caps brightness
   at 130/255, with a comment blaming heat. On a battery with internal resistance, add a few 100 nF across the
   matrix plus bulk at the cell input.
5. **Heat.** On USB the LDO drops 1.4 V at about 100 mA, beside the ESP32 under a lit matrix. On a LiPo the drop is
   0.2–0.9 V.
6. **The IMU is out of stock.** QMI8658C has 0 stock at JLC (2026-10-17). QMI8658A (C3021082, 13k) is the current
   part in the same LGA-14 with the same pins. LSM6DS3TR-C (C967633) also fits the footprint but needs another driver.
7. **The LEDs are not stocked.** The 0807 WS2812B exists at JLC only as a global-sourcing entry with no stock. The
   Worldsemi WS2812B-2020-V6 (C52917434, 932k) is in stock and rated 3.3–5.3 V; LCSC lists its quiescent current
   as 1 µA (confirm in the datasheet; classic WS2812B draw about 1 mA each when dark).
8. **The antenna is not stocked.** CA-C03 is a JLC global-sourcing entry; see D6.
9. **No ESD protection** on USB.

## 3. Battery: power budget and runtime

What firmware 1.4.0 does (`Herz_Schwarm_CCC_V.ino`): the radio never sleeps (`WiFi.setSleep(false)`), ESP-NOW on
channel 13, a broadcast every 50 ms at 13 dBm (`esp_wifi_set_max_tx_power(52)`), a 50 Hz render loop. The heart
lights 40 of 64 pixels in (255, 0, 150), pulsing between 100/255 and 255/255, under a global brightness of
4–130/255 set by how close other badges are. Numbers from the datasheet summaries in `docs/datasheets/`:

| Load | Current | Source |
| --- | --- | --- |
| ESP32-S3, radio receiving | 88–91 mA, plus about 1 mA average for 20 packets a second | ESP32-S3 datasheet p62 |
| WS2812B-2020-V6 | 12 mA per colour at full PWM, 36 mA white; 1 µA each when dark | V6 datasheet p1, p3, p4 |
| Heart (40 px, duty from colour × pulse × brightness) | 35 mA quiet, 139 mA typical crowd, 271 mA packed crowd | `sim/model.py` |
| White flash at brightness 130 (virus, strobe) | 1.18 A on top, 150 ms on / 150 ms off | 64 × 36 mA × 130/255 |
| Full white at 255 | 2.3 A | above the JST PH's 2 A and D101's continuous rating: firmware must never do this (D17) |

Runtime from full to VSW = 3.4 V (the proposed firmware shutdown), simulated in `sim/runtime.py`
([results](sim/results/runtime.md), [plot](sim/results/runtime.png)):

| Cell | Quiet | Typical crowd | Packed crowd | Typical, brightness capped at 60 on battery |
| --- | --- | --- | --- | --- |
| 103030, 1000 mAh as listed (real cells: below) | 7.5 h | 4.1 h | 2.6 h | 6.0 h |
| 102030, 600 mAh | 4.5 h | 2.5 h | 1.5 h | 3.6 h |
| 25 × 30 mm, 350 mAh | 2.6 h | 1.4 h | 0.9 h | 2.1 h |

Real 103030 cells hold less than 1000 mAh. Makers that publish datasheets rate the size at 800–900 mAh, and with
its protection board it measures about 10.5 × 30.5 × 32–33 mm (battery report,
`research_notes/Badge battery options/suppliers_asia.md`). The same simulation, with cell resistances assumed:

| Cell | Typical, capped at 60 | Quiet / typical / packed, uncapped |
| --- | --- | --- |
| 850 mAh | 5.1 h | 6.4 / 3.5 / 2.2 h |
| 900 mAh | 5.4 h | 6.8 / 3.7 / 2.3 h |
| 103035, about 1100 mAh, 37 mm long with its board, so it needs a 37 mm board | 6.6 h | 8.3 / 4.5 / 2.9 h |

With the brightness cap on battery (D17), a real 850–900 mAh 103030 just reaches the 5 h end of the 5–8 h target;
without the cap, no cell that fits does. The next lever is the radio's 90 mA floor (listen windows locked to the
shared beat; the mesh report estimates 25–50 mA, about 8–10 h). The other lever is a longer board for a 103035. The cell's
open-circuit curve and internal resistance in the model are typical values; a measured discharge of the chosen
cell should replace them.

## 4. Architecture (battery badge)

```
VBUS ── SS14L (D101) ─────────┐
VBAT ── AO3401A Q101 ─────────┴── VSYS ── AO3401A Q102 (off switch) ── VSW ──┬── 64 × WS2812B-2020-V6
     └─ B5819WS D104 (across Q101)                                           ├── SN74LVC1T45: GPIO14 → LED_DIN
VBUS ── TP4056 (400 mA) ── VBAT ── Q103 (reverse guard) ── JST PH ── LiPo   └── ME6217 LDO ── 3V3 ── ESP32-S3, IMU
VBAT ── 1M/1M ── GPIO1 (ADC1)    VBUS ── 100k/100k ── GPIO2 (ADC1)    TP4056 CHRG ── red LED (front)
USB D± ── USBLC6-2SC6 ── 22 Ω ── GPIO19/20
```

- **Load sharing.** With USB present the load runs from VBUS through D101 and the charger sees only the cell;
  without USB, Q101 (gate on VBUS, R105 = 10 kΩ to GND) connects the cell. D104 across Q101 carries the load while
  VBUS decays after unplugging: `sim/unplug.py` ([results](sim/results/unplug.md)) shows 3V3 at 3.16 V at 10 %
  charge with it, 2.87 V without (D13).
- **Off switch.** Q102 in series with the load, its gate pulled to VSYS by 100 kΩ and to GND (on) by the slide
  switch. The MSK12C02 is rated 50 mA, so it only switches the gate. The charger sits before the switch, so the cell
  charges with the badge off.
- **Reverse-polarity guard.** Q103 between the JST and VBAT, gate to GND: the body diode conducts for a correctly
  wired cell and the channel then turns on; a reversed cell leaves it off while USB is unplugged (D12).
- **LEDs from the system rail.** VSW is 4.2–3.4 V on battery and about 4.6 V on USB, inside the V6's 3.3–5.3 V
  range; the firmware shutdown at VSW 3.4 V keeps them inside it. A 5 V boost would add an inductor, loss and parts.
- **Level shifter.** The V6's input threshold is 0.55 × VDD (2.5 V at 4.6 V), so 3.3 V logic would just do, but the
  SN74LVC1T45 (VCCA 3V3, VCCB VSW) keeps margin and is high-impedance when either side is off.
- **3V3.** ME6217: 100 mV typical, 180 mV maximum dropout at 300 mA; the ESP32-S3 runs to 3.0 V.
- **Charger.** TP4056 (UMW, ESOP-8, exposed pad to the ground plane with vias): 1200 V / R_PROG, 3.0 kΩ → 400 mA,
  C/10 termination, 2.9 V trickle. `sim/charge.py` ([results](sim/results/charge.md)): the 1000 mAh cell is at 80 % in
  1.9 h and full in 2.6 h, with 0.55 W peak in the charger (rated 1.5 W). The TP4054 first chosen would have spent most
  of the charge in thermal limit, above its 250 mW absolute maximum (D14). With the badge on and charging, USB
  supplies up to about 0.4 A + the load: fine for a phone charger, marginal on a 500 mA USB-A port.
- **White flash.** `sim/flash_sag.py` ([results](sim/results/flash_sag.md)): with the 1000 mAh cell 3V3 stays at
  2.88 V or more down to 5 % charge; the 600 and 350 mAh cells brown out at 5–10 %.
- **Sense.** 1 MΩ / 1 MΩ with 100 nF from VBAT to GPIO1 (about 2 µA); VBUS through 100 kΩ / 100 kΩ to GPIO2.
- **From the reference, fixed:** 1 µF on CHIP_PU, 0.1 µF and 1 µF on VDD_SPI, I²C pull-ups, 100 nF per LED row, USB
  ESD, 12 pF crystal caps for the crystal's 10 pF load (D16).
- **Antenna.** Walsin RFANT3216120A5T in the bottom-left corner, 6 × 6 mm keep-out, 6.8 nH series at the antenna
  (D15, `docs/datasheets/antennas.md`).
- **Kept:** GPIO0 BOOT, GPIO14 LED data, the chain order, IMU on GPIO10–13 (address 0x6B, SA0 low), the USB pins,
  RESET. GPIO45 stays unconnected: it must be low at reset for the 3.3 V in-package flash.

## 5. Battery safety

The 1000 mAh cell stores 3.7 Wh. Behind its 0.12 Ω internal resistance (`sim/model.py`) it can push well over 10 A
into a short. Hundreds of people will wear the badge, charge it in tents and carry it in bags. WHY2025's badge was
declared a fire hazard during the event ([advisory](https://wiki.why2025.org/Badge/Fire_hazard)):
- its two 18650 cells had no protection;
- traces ran 0.4 mm from ground under 10–30 µm of solder mask;
- in a 20 A test the protection reacted too slowly.

The aim here is R7: no single fault starts a fire. The faults covered are a short on the board, a bad cell, a hot
tent and a crushed pouch. Rules for buying, labelling, transport and disposal are in
[the battery report](../reports/Badge%20battery%20options.md).

| # | Hazard | The badge now | Required (D18, D19) | Proposed for routing |
| --- | --- | --- | --- | --- |
| 1 | A short on the board side: a solder bridge, a cracked capacitor, a metal lanyard clip across bare pads | No fuse: only the cell's protection circuit (PCM) opens a short. The pads of TP201–TP204 (TX, RX, 3V3, GND), J102 and U101 are bare on the back under the cell | Protected cells only, with a PCM trip test on samples from every batch (D18); an insulating sheet over the back (D19) | F101: a 2 A fast-acting 1206 fuse between J102 pin 2 and Q103. Littelfuse 0466002.NRHF (C3105): 31 mΩ cold, $0.05–0.07, Extended, 31k stock. It drops about 40 mV in a white flash (1.3 A). A dead short of the cell (10–35 A) opens it within a few ms (melting I²t 0.23 A²s). Re-run `sim/flash_sag.py` with the 31 mΩ before adding it |
| 2 | An unprotected, reversed or mislabelled cell | Q103 blocks a reversed cell only while USB is unplugged (D12) | Cells bought with a PCM and with the JST fitted pin 2 = +; meter every cell before plugging it in (D5, D18) | — |
| 3 | Charging below 0 °C or above 45 °C: a badge in a tent in the sun, or plugged in straight from a cold car at Congress | TEMP is tied to GND, so the TP4056 does not check temperature (datasheet p3) | — | An NTC on TEMP, needed for IEC 62368-1 M.4.2 (below): Murata NCP15XH103F03RC (C77131, 10 kΩ, B 3380 K, 0402, $0.02, 306k stock), under the middle of the cell and away from U101, D101 and U201. Use 5.6 kΩ from VBUS to TEMP and 120 kΩ from TEMP to GND. The TP4056 pauses charging when TEMP leaves 45–80 % of VCC (p13–14); these values put the limits at about 0.5 °C and 46 °C. The divider draws 0.34 mA, and only from USB. Li-ion is not charged below freezing or fast-charged above 45 °C ([BU-410](http://www.batteryuniversity.com/article/bu-410-charging-at-high-and-low-temperatures/)) |
| 4 | Heat into the cell while charging | U101 (up to 0.55 W, `sim/charge.py`) and D101 (up to 1.4 A on USB) sit on the back under the cell, with nothing between them and the pouch | The sheet and spacer of D19 | Move U101, R103 and D101 out of the cell's outline if routing allows. Either way, measure the cell surface over U101 during a full charge (section 9) |
| 5 | Charge current too high for the cell | 400 mA (R103 = 3.0 kΩ) | Cells of 800 mAh or more whose datasheet allows at least 0.5C charge; 400 mA is 0.4C for 1000 mAh. A smaller cell needs a new R103: 400 mA into section 3's 350 mAh cell is 1.1C | — |
| 6 | Discharge beyond the cell's rating | White flash: 1.18 A plus about 0.1 A. Full white: 2.3 A (section 3) | A cell rated for at least 1C continuous; a PCM over-current trip at 2 A or more, so a flash does not cut the badge off; the power limit of D17 | — |
| 7 | Over-discharge after the event | Deep sleep at VSW 3.4 V (D17) is not off. An estimated 0.18–0.28 mA still flows: the ME6217 (100 µA typical, more near dropout, datasheet p4, p7), 64 dark LEDs (64 µA), the ESP32-S3 (8 µA, p63), plus the IMU and the level shifter. The 4 % left at 3.4 V (about 40 mAh, `sim/model.py`) lasts one to two weeks. Then the PCM disconnects, and the cell keeps self-discharging. Switched off (Q102 open), only the VBAT divider (2 µA), the TP4056 (≤ 1 µA, p5) and the PCM draw current | The off switch is the storage and transport state: the handout card says so. Store at about 40–60 % charge; ship by air at 30 % or less (IATA, also for cells packed with equipment since 2026) | Measure both currents (section 9). If deep sleep is well above 0.2 mA, let the firmware switch the matrix supply |
| 8 | A crushed, punctured or bent pouch | With the cell flush to the top edge, its 30 × 30 mm outline covers two connectors. J102 is a side-entry JST PH, 5.5 mm tall (datasheet p3). J101's USB-C shell reaches about 4 mm into the outline (y 25.7–35.2). A cell laid flat rests on both connector edges, and a lanyard pull presses it onto them | A spacer at least as thick as the tallest part under the cell, so the pouch lies on a flat face, over a polyimide sheet on the board (D19). Keep pressure off the cell's PCM tab and leads. Tape the leads down on the cell, so the plug carries no strain | Move J102 out of the cell's outline: into the bottom strip, or to the right edge below y 30. The cell can then lie on a thin pad. Check the USB-C overlap at the same time |
| 9 | Swelling with age, overcharge or heat | Nothing constrains the cell or watches it | Leave the cell room to grow: no clamping case. Retire any cell that is puffy, dented or hot | — |
| 10 | A cell the user cannot change. EU 2023/1542 Art. 11 applies to badges placed on the EU market from 18 Feb 2027, which covers a summer 2027 camp but not the December 2026 Congress | The cell is on a JST plug, which is fine. Prying a pouch off strong foam tape can bend or puncture it, and the Commission's guidelines ask for removal without damage to the battery or the device (C(2026) 5032) | Hold the cell with a reusable fastener: hook-and-loop on the spacer (as MCH2022 did), a strap, or stretch-release strips (D19). Publish removal instructions online, and keep spare cells (and fasteners, if they are not reusable) for 5 years after the last badge (Art. 11(7)) | — |

Two standards shape the proposals above:
- **IEC 62368-1 Annex M.4.2**, for the badge as an end product, requires charging to stop above the cell's
  charge-temperature limit, even under a single fault. With TEMP tied to GND the badge cannot meet it, so the NTC
  of hazard 3 is needed for any safety claim, not just nice to have.
- **EU 2023/1542** also requires a crossed-out bin on the cell itself, about 5 mm square on a 30 × 30 mm face. That
  belongs in the cell order (D18).

Who places the badges on the EU market is an organisational question, not a board one. It needs an EU-based
operator. See `research_notes/Badge battery options/regulations.md`.

## 6. Parts (JLC stock and price checked 2026-10-17 with bomi)

The chosen parts are in BOM.md with prices at production quantities; datasheet summaries in `docs/datasheets/`.
Second sources and alternatives kept in view:

| Function | Chosen | Alternative | Note |
| --- | --- | --- | --- |
| MCU | ESP32-S3FH4R2 C3013940 (3,838) | ESP32-S3-MINI-1-N4R2 C3013941 (3,014) | the module is a layout change |
| LEDs | WS2812B-2020-V6 C52917434 (932k) | XL-2020RGBC-2812B C5349955 (20k) | the alternative needs 3.5 V minimum |
| IMU | QMI8658A C3021082 (13k) | LSM6DS3TR-C C967633 (14k) | same pins, other driver |
| Charger | TP4056 (UMW) C725790 (252k) | TP4056 TOPPOWER C16581 (52k) | |
| Antenna | Walsin RFANT3216120A5T C127629 (3,773) | Kinghelm KH5220-A36 C484543 (6,566) | stock covers about 1000 boards; reserve before ordering |
| USB ESD | ST USBLC6-2SC6 C7519 (35k) | TECH PUBLIC C2827654 (58k) | the copy is rated 5.0 V |
| Crystal | JGHC 40 MHz 3225 C426988 (2,390) | any 3225 40 MHz, 10 pF load | thin stock |

## 7. Decisions

| # | Date | Decision | Why |
| --- | --- | --- | --- |
| D1 | 2026-10-17 | The hardware lives in `herz_badge/` in this repo, laid out by `pcbkit new` without its own git | firmware and hardware version together |
| D2 | 2026-10-17 | The reference is redrawn from the vendor's netlist with the vendor's designators, and checked pin for pin | the PDF carries the netlist; tracing photos would guess |
| D3 | 2026-10-17 | The clone keeps GPIO14 for LED data, GPIO0 for BOOT, the LED chain order and the IMU pins | one firmware binary for both boards |
| D4 | 2026-10-17 | WS2812B-2020-V6 on the switched system rail (VSW), no 5 V boost | rated 3.3–5.3 V, in stock, no inductor |
| D5 | 2026-10-17 | The cell plugs into a JST PH 2.0 (S2B-PH-SM4-TB) at the right edge, pin 2 = +VBAT, pin 1 = GND | the common LiPo plug; Adafruit's polarity, which many cells do not follow, so every cell is checked with a meter |
| D6 | 2026-10-17 | ESP32-S3FH4R2 chip (as the reference) with a Walsin RFECA3216060A1T 3216 ceramic antenna (C127620, $0.056, Kinghelm copy C411566), behind a pi network fitted as 0 Ω with both shunts open | cheapest stocked 2.4 GHz chip antenna; the network leaves room to tune with a VNA |
| D7 | 2026-10-17 | No 2×10 header; pads for TX, RX, 3V3, GND and the matrix's DOUT | no firmware uses the header; its edges went to the battery parts |
| D8 | 2026-10-17 | Outline 29 × 34 mm, 4 layers, LEDs at 3.2 mm pitch; a 7.7 mm strip below the matrix carries the parts with holes or keep-outs (USB-C, slide switch, antenna) | the USB-C and switch have drilled pegs that cannot sit under the front LEDs; the 2020 footprint's courtyard is 3.2 mm; "a bit larger" was fine |
| D9 | 2026-10-17 | VBAT through 1 MΩ / 1 MΩ to GPIO1, VBUS through 100 kΩ / 100 kΩ to GPIO2, the charge LED on the front below the matrix | the cell covers the back; both sense pins are ADC1 and not strapping pins |
| D10 | 2026-10-17 | No ESD part on USB yet | no room was planned for it; revisit when routing |
| D11 | 2026-10-17 | Outline 30 × 34 mm (was 29 × 34, D8) | the shortlisted cell, a 103030 1000 mAh pouch at CHF 0.68–0.85, is 30 × 30 mm and should not overhang |
| D12 | 2026-10-17 | Q103 (AO3401A, gate to GND) between the JST and VBAT; reverses D10: USBLC6-2SC6 (U103, C2827654) on D± and VBUS | Alibaba cells come wired either way: with USB unplugged a reversed cell is blocked. With USB plugged in at the same time Q103 turns on from the charger's output and only limits the damage, so cells still get checked with a meter |
| D13 | 2026-10-17 | D104 (B5819WS) across Q101, and R105 = 10 kΩ (was 100 kΩ) | sim/unplug.py: with 9.4 µF on VBUS and only 100 kΩ to discharge it, Q101's gate stays high for hundreds of ms after unplugging and the load runs through Q101's body diode: 3V3 fell to 2.87 V at 10 % charge, 0.07 V above the assumed brownout level (a first model with a weaker body diode browned out). With the fix, 3.16 V |
| D14 | 2026-10-17 | TP4056 (UMW, ESOP-8) at 400 mA instead of the TP4054, and SS14L (SOD-123FL) for D101 instead of the B5819WS | datasheets: the TP4054's absolute maximum is 250 mW, and a 300 mA charge from 5 V dissipates 0.24–0.6 W; the TP4056 is rated 1.5 W and charges the 1000 mAh cell in 2.6 h. D101 carries the whole load on USB (up to about 1.4 A in a white flash); the B5819WS's 250 mW package allows about 0.55 A continuous |
| D15 | 2026-10-17 | Antenna: Walsin RFANT3216120A5T (C127629) with 6.8 nH series (L203, at the antenna) in a 6 × 6 mm corner keep-out, replacing the RFECA3216060A1T (D6) | the only candidate whose datasheet layout is a corner of a small board (20 × 45 mm, 6 × 6 mm clearance, p3); the RFECA3216060A1T wants a mid-edge cut-out with 30 mm of ground along the edge, which the badge does not have. Stock (3,773) covers about 1000 boards; runner-up Kinghelm KH5220-A36 (docs/datasheets/antennas.md) |
| D16 | 2026-10-17 | Crystal caps 12 pF (was 10 pF); ST's USBLC6-2SC6 (C7519) instead of the TECH PUBLIC copy | the crystal is listed with a 10 pF load: 12 pF per side plus about 4 pF of board gives 10 pF. The copy's working voltage is 5.0 V, VBUS may be 5.25 V |
| D17 | 2026-10-17 | Firmware for the battery badge: cap brightness at 60 on battery (VBUS_SENSE low), `FastLED.setMaxPowerInVoltsAndMilliamps(4, 800)` always, deep sleep below VSW 3.4 V (read VBAT on GPIO1) | the cap gives 6.0 h typical on 1000 mAh (4.1 h without); the power limit keeps a white flash below the JST's and D101's ratings; 3.4 V keeps the LEDs above their 3.3 V minimum |
| D18 | 2026-10-18 | Buy only cells that meet all of these: a protection circuit (overcharge, over-discharge, over-current trip at 2 A or more, short circuit); a datasheet allowing at least 0.5C charge and 1C continuous discharge; a UN 38.3 test summary and an IEC 62133-2 test report for the exact model; the crossed-out bin and the capacity printed on the cell; the JST PH fitted with pin 2 = +. Check every batch. Every cell: dimensions, polarity and open-circuit voltage. Samples: PCM short-circuit and over-current trip, and a capacity test | the board has no fuse, and Q103 covers a reversed cell only without USB, so the PCM is the only short protection (section 5); WHY2025 handed out unprotected cells |
| D19 | 2026-10-18 | Between the board and the cell: a polyimide sheet over the whole back, then a closed-cell foam spacer as thick as the tallest part under the cell (J102, 5.5 mm), so the pouch lies flat. The spacer is stuck to the board. The cell is held to the spacer by a reusable fastener (hook-and-loop, a strap, or stretch-release strips), not permanent tape. Tape the cell's leads down on the cell side | bare 3V3, GND and VBAT pads, a 5.5 mm connector and the USB-C shell all sit inside the cell's outline (section 5, hazards 1 and 8); from 18 Feb 2027 the user must be able to change the cell without damaging it (hazard 10) |

## 8. Block designs (badge)

Generated by `scripts/sch_badge.py`; designators 1xx power, 2xx MCU, 3xx LEDs (D301 is chain index 0).

| Block | Parts | Notes |
| --- | --- | --- |
| USB-C | J101, R101, R102, C101, U103 | 5.1 kΩ CC pull-downs (5 V sink), USBLC6-2SC6 on D± and VBUS, D± through 22 Ω (R203/R204) to GPIO19/20 |
| Load sharing | D101, Q101, R105, D104 | VBUS → SS14L → VSYS; AO3401A from VBAT to VSYS, gate on VBUS with 10 kΩ to GND; B5819WS across it |
| Charger | U101, R103, C102, C103, D102, R104 | TP4056 (ESOP-8, pad to GND), R_PROG 3.0 kΩ = 400 mA, TEMP and EP to GND, CE to VBUS; CHRG drives the red front LED from VBUS |
| Cell | J102, Q103 | JST PH (pin 2 +), Q103 reverse guard to VBAT; VBAT → R107/R108 (1 MΩ each) + C108 → GPIO1 |
| Off switch | Q102, R106, SW101 | AO3401A VSYS → VSW, gate pulled to VSYS by 100 kΩ, slide switch pulls it to GND (on) |
| 3V3 | U102, C105–C107 | ME6217C33M5G from VSW |
| MCU | U201, Y201, L201, C201–C212, L202 | as the reference, plus 1 µF on CHIP_PU (C210), 100 nF + 1 µF on VDD_SPI (C211/C212), 12 pF crystal caps |
| RF | C213, R207, C215, L203, AE201 | pi network at the chip (shunts open, 0 Ω series), 6.8 nH at the antenna; Walsin RFANT3216120A5T in the 6 × 6 mm bottom-left keep-out |
| Buttons | SW201 RESET, SW202 BOOT | as the reference; BOOT on GPIO0 is the Morse button |
| IMU | U202, C216, C217, R205, R206 | QMI8658A on GPIO10–13 as the reference, with 10 kΩ I²C pull-ups |
| LED data | U301, C301, C302, R301 | SN74LVC1T45: GPIO14 (3V3) → VSW, 33 Ω into the first LED |
| Matrix | D301–D364, C303–C312 | 64 × WS2812B-2020-V6 on VSW, row-major as the firmware; 100 nF per row and 2 × 10 µF |
| Pads | TP201–TP204, TP301 | TX, RX, 3V3, GND; DOUT of the last LED |

GPIO: 0 BOOT, 1 VBAT_SENSE, 2 VBUS_SENSE, 10–13 IMU (INT1, SDA, SCL, INT2), 14 LED data, 19/20 USB, 43/44 TX/RX.
The firmware needs nothing new to run; battery and charge readings are new code.

## 9. To measure on a real badge

- LED pitch, the corner where chain index 0 sits, and whether rows alternate direction (light LEDs 0, 1, 8 alone).
- Board thickness, USB-C type (mid-mount or top-mount), crystal package, button part.
- Current from a USB meter: idle, heart at minimum and maximum proximity, virus flash. This replaces the estimates
  in section 3.

On the first battery badges (section 5):

- Cell current in deep sleep at VSW 3.4 V, and switched off (hazard 7).
- Cell surface temperature over U101 during a full charge at 25 °C, with the D19 stack in place (hazard 4).
- The chosen cell's PCM: the over-current trip with a white flash running, and the short-circuit cut-off (D18).
