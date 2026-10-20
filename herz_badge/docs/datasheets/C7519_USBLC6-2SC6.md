# USBLC6-2SC6 (C7519)
Source: docs/datasheets/C7519_C7519.pdf, fetched 2026-10-17 by scripts/fetch_datasheets.py

STMicroelectronics USBLC6-2 (SC6 = SOT-23-6L), Doc ID 11265 Rev 5 (Oct 2011). For the TECH PUBLIC clone see C2827654_USBLC6-2SC6.md.

## Key numbers

| Parameter | Min / Typ / Max | Conditions | Page |
|---|---|---|---|
| Pinout | 1 I/O1, 2 GND, 3 I/O2, 4 I/O2, 5 VBUS, 6 I/O1 | functional diagram, top view | p1 |
| Leakage I_RM | – / 10 / 150 nA | V_RM = 5.25 V | p2 |
| Leakage vs T_J | ≈x4 at 75 °C, ≈x10 at 100 °C, ≈x20 at 125 °C (relative to 25 °C) | V_BUS = 5 V, Fig. 4 | p3 |
| V_BR (VBUS-GND) | 6 V min | I_R = 1 mA | p2 |
| V_F | 1.1 V max | I_F = 10 mA | p2 |
| Clamping V_CL | 12 V max @ 1 A; 17 V max @ 5 A | 8/20 µs, I/O to GND | p2 |
| C_I/O-GND | – / 2.5 / 3.5 pF (ΔC 0.015 pF) | V_R = 1.65 V | p2 |
| C_I/O-I/O | – / 1.2 / 1.7 pF (ΔC 0.04 pF) | V_R = 1.65 V | p2 |
| ESD | 15 kV air, 15 kV contact (IEC 61000-4-2), 25 kV MIL-STD | | p2 |
| T_j | -40 to +125 °C | | p2 |
| IEC 8 kV contact calc. | V_CL+ ≈ +31 V, V_CL- ≈ -13 V before trace inductance | example | p4 |

## Notes for this board
- Same pinout as the TECH PUBLIC part, so the two are interchangeable on one footprint.
- Leakage is specified at 5.25 V, which covers a USB VBUS at the top of tolerance. The clone only rates 5.0 V.
- 6 nH of trace adds ≈144 V per trace during an 8 kV hit (p4). Keep the I/O, VBUS and GND traces from the connector short, and put the part right at the USB-C connector (p5, p6).
- The VBUS pin needs no current. It only biases the rail-to-rail diodes and the internal Zener; leakage exists only while USB is plugged in.
- D+/D- capacitance (≤3.5 pF to GND) is fine for USB 2.0 full/high speed.
