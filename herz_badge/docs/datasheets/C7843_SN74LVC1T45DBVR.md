# SN74LVC1T45DBVR (C7843)
Source: docs/datasheets/C7843_SN74LVC1T45DBVR.pdf, fetched 2026-10-17 by scripts/fetch_datasheets.py

TI single-bit dual-supply transceiver, SCES515I (rev. May 2009), DBV = SOT-23-6.

## Key numbers

| Parameter | Min / Typ / Max | Conditions | Page |
|---|---|---|---|
| Pinout (DBV) | 1 VCCA, 2 GND, 3 A, 4 B, 5 DIR, 6 VCCB | top view | p1 |
| Direction | DIR = H: A -> B; DIR = L: B -> A; DIR is referenced to VCCA | | p1, p2 |
| VCCA / VCCB range | 1.65 to 5.5 V each (abs max -0.5 to 6.5 V) | | p3, p4 |
| VIH (data, DIR) | 2.0 V min | VCCI = 3.0-3.6 V | p4 |
| VIL (data, DIR) | 0.8 V max | VCCI = 3.0-3.6 V | p4 |
| VIH / VIL other VCCI | 0.7 x VCCI / 0.3 x VCCI | VCCI 4.5-5.5 V, or not listed | p4 |
| VOH | VCCO - 0.1 V @ -100 µA; 2.4 V @ -24 mA (3 V); 3.8 V @ -32 mA (4.5 V) | min, -40 to 85 °C | p5 |
| I_OH / I_OL rec. | ±24 mA (VCCO 3-3.6 V), ±32 mA (4.5-5.5 V) | | p4 |
| I_off (partial power-down) | ±1 µA (25 °C), ±2 µA (-40 to 85 °C) max | either VCC = 0 V, V_I/V_O 0-5.5 V | p5 |
| VCC isolation | either VCC at GND -> both ports Hi-Z | | p1 |
| I_CCA + I_CCB | 4 µA max | static, V_I = VCCI or GND | p5 |
| ΔI_CC | 50 µA max | input at VCC - 0.6 V | p5 |
| t_PD A->B (VCCA 3.3 V) | 0.7-5.8 ns (VCCB 3.3 V); 0.7-4.4 ns (VCCB 5 V) | | p7 |
| Input edge rate | ≤10 ns/V (data, VCCI 3-3.6 V); ≤5 ns/V (control) | | p4 |
| Max data rate | 420 Mbps (3.3 -> 5 V) | | p1 |

## Notes for this board
- VCCA = 3.3 V and VCCB = VSW (≈3.0-4.7 V) are both inside 1.65-5.5 V. VSW between 3.6 and 4.5 V falls between the tabulated VOH rows, but at WS2812 load currents (µA) VOH ≈ VCCB - 0.1 V.
- DIR must be tied high (to VCCA / 3.3 V) for A (ESP32) -> B (LEDs). Tied low, it would drive the ESP32 pin instead.
- ESP32 VOH ≥ 0.8 x 3.3 = 2.64 V meets VIH = 2.0 V.
- Data inputs are always active and must not float (p1). A weak pull-down on A keeps the LED data line low while the ESP32 GPIO is still floating at boot.
- When the slide switch is off, both rails collapse together (the LDO is fed from VSW). I_off and VCC isolation keep the ports Hi-Z while one rail decays faster than the other, so nothing back-powers.
