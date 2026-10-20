# Herz-Schwarm Badge: design notes

Status (2026-10-17): reference reverse-engineered and redrawn (`boards/reference/`, netlist identical to the
vendor's). Battery badge (`boards/badge/`): datasheets summarised, power path simulated (`sim/`), parts revised
after both (D12–D16), placed on 30 × 34 mm, 4 layers, not routed; order files for a JLC quote. Next: the quote,
a real badge measured (section 8), the firmware changes of D17, then routing.

## 1. Requirements

- **R1 Same badge.** Runs the badge firmware (1.4.0) unchanged: 8×8 RGB matrix on GPIO14 in the same chain order,
  BOOT button on GPIO0, ESP32-S3 with ESP-NOW, USB-C for flashing.
- **R2 Battery.** Runs from one LiPo cell, charges from USB-C, and keeps running while it charges.
- **R3 Size.** About the reference's 25 × 25 mm, with the cell behind the board.
- **R4 Off switch.** Cuts the load completely for storage and transport; charging still works when off.
- **R5 Battery voltage.** Firmware can read it, for a low-battery warning and a brightness cap on battery.
- **R6 Made at JLC.** Assembled at JLC from stocked parts; Basic parts where the function allows.
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
mirror-symmetric in every row, so it would look right either way. Measure it (section 8) before placing the clone's
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
| 103030, 1000 mAh (CHF 0.68–1.19) | 7.5 h | 4.1 h | 2.6 h | 6.0 h |
| 102030, 600 mAh | 4.5 h | 2.5 h | 1.5 h | 3.6 h |
| 25 × 30 mm, 350 mAh | 2.6 h | 1.4 h | 0.9 h | 2.1 h |

The 1000 mAh cell meets the 5–8 h target only with the brightness cap on battery (D17); the radio's 90 mA
floor is the next lever (listen windows locked to the shared beat), not needed for the target. The cell's
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

## 5. Parts (JLC stock and price checked 2026-10-17 with bomi)

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

## 6. Decisions

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

## 7. Block designs (badge)

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

## 8. To measure on a real badge

- LED pitch, the corner where chain index 0 sits, and whether rows alternate direction (light LEDs 0, 1, 8 alone).
- Board thickness, USB-C type (mid-mount or top-mount), crystal package, button part.
- Current from a USB meter: idle, heart at minimum and maximum proximity, virus flash. This replaces the estimates
  in section 3.
