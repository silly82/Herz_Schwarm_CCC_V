# S2B-PH-SM4-TB(LF)(SN) (C295747)
Source: docs/datasheets/C295747_S2B-PH-SM4-TB-LF-SN-.pdf, fetched 2026-10-17 by scripts/fetch_datasheets.py

JST PH series catalogue pages (2.0 mm pitch). The part is the 2-circuit SMT side-entry header (SM4 type).

## Key numbers

| Parameter | Min / Typ / Max | Conditions | Page |
|---|---|---|---|
| Current rating | 2 A AC/DC | with AWG #24 wire | p1 |
| Voltage rating | 100 V AC/DC; withstand 800 VAC / 1 min | | p1 |
| Contact resistance | 10 mΩ max initial, 20 mΩ after environmental tests | | p1 |
| Temperature | -25 to +85 °C, including self-heating | | p1 |
| Wire range (mating SPH-002T) | AWG #32 to #24 | | p1, p2 |
| Header size (2 ckt, side entry) | B = 7.9 mm wide, A (pin span) = 2.0 mm; height 5.5 mm; depth 6 mm + (2.6) tail | | p3 |
| Signal pads | 1.0 mm wide (min), 2.0 mm pitch, spanning from ≤5.5 mm to ≥9 mm behind the wafer end face | component-side view | p1 |
| Solder-tab pads | 1.5 x 3.4 mm, at the mating-face end; inner edge 1.6 mm from the nearest signal-pad centre | component-side view | p1 |
| Mating face | side opposite the signal pads; the plug enters over the tab-pad end (side view: body 7.6, overall (9.6), lead tail (1)) | | p1 |
| Pin 1 | component-side view with mating face up: circuit No. 1 is the right-hand signal pad; looking into the mating face: left-hand contact | | p1, p3 |
| Mating housing | PHR-2; contacts SPH-002T-P0.5S | | p2 |

## Notes for this board
- 2 A rating vs. load: 64 LEDs at full white (2.3 A) plus the ESP32 exceeds the connector rating on battery. A firmware current cap of ≤~1.5 A leaves margin.
- Place the mating face (the tab-pad end) toward the board edge so the plug can enter. The signal pads sit 5.5-9 mm behind it, at the back of the body.
- The datasheet does not define battery polarity. Pre-wired LiPo cells with PH plugs come in both polarities, so mark + on the silkscreen and check the cell before plugging in.
- Contact resistance (≤20 mΩ) adds to the two FET R_DS(on) in the battery path.
