# 2.4 GHz chip antennas for the badge

Source: C127620_RFECA3216060A1T.pdf, C411566_C411566.pdf, C127629_C127629.pdf, C293767_C293767.pdf,
C127611_C127611.pdf, C484543_C484543.pdf, C486321_C486321.pdf (LCSC datasheets in this folder), fetched 2026-10-17.
Stock and prices are JLC/LCSC on 2026-10-17. "p. N" is the PDF page; in C411566 the printed page number is N+1.
Sunlord SLDA31-2R400G-S2TF (C370395) had no datasheet on LCSC and is not checked.

The badge corner: 4 layers, 29 × 34 mm, antenna on the back in the bottom-left corner, keep-out currently
x 0–8.2, y 28–34 (8.2 mm along the bottom edge, 6 mm up), at most about 10 × 7 mm available; the ESP32-S3 sits about
6 mm above and to the right with LNA_IN toward the corner.

## Performance and evaluation board

| Part (LCSC) | Size L × W × T, mm | Band | Gain, efficiency (as printed) | S11 / VSWR on the eval board | Eval board | Match on the eval board |
|---|---|---|---|---|---|---|
| Walsin RFECA3216060A1T (C127620) | 3.1 × 1.6 × 0.6 (p. 2) | 2.400–2.4835 GHz (p. 3) | 2 dBi typ. (p. 3); plane averages −1.51 / −0.57 / −1.17 dBi (Y-Z / X-Z / X-Y); no efficiency (p. 5) | VSWR 2.1 max. (p. 3); −10.6 / −19.3 / −9.6 dB at 2.40 / 2.45 / 2.50 GHz (p. 4) | 90 × 40 mm ground, 0.8 mm FR4 (p. 3–4) | one 0402 from pin 2 to GND, value not given (p. 3) |
| Kinghelm KH-RFECA3216060A1T, a copy (V09 sheet, C411566) | same (p. 1) | same (p. 2) | 2 dBi typ.; plane averages at 2.45 GHz: type 1 −2.88 / −0.21 / −2.48 dB, type 2 −2.62 / −0.62 / −2.61 dB (Z-X / Z-Y / X-Y); no efficiency (p. 6–7) | VSWR 2.0 max.; type 1 −11.0 / −17.0 / −10.8 dB, type 2 −14.7 / −20.2 / −11.4 dB at 2.40 / 2.45 / 2.50 GHz (p. 4–5) | 90 × 40 mm, 0.8 mm (p. 2–5) | same 0402 to GND, no value (p. 2–3) |
| Walsin RFANT3216120A5T (C127629) | 3.2 × 1.6 × 1.2 (p. 2) | 2450 ± 50 MHz; unmatched Fc 2.9 GHz, "must be adjusted to 2.45 GHz with matching circuit" (p. 3) | 2 dBi typ. (p. 3); peak 2.12 dBi; plane averages +0.89 / −1.85 / −2.56 dBi (Y-Z / X-Z / X-Y), mean of the three ≈ −0.9 dBi (computed); no efficiency (p. 5) | VSWR 2 max. (p. 3); −12.2 / −15.5 / −13.8 dB at 2.40 / 2.45 / 2.50 GHz, VSWR 1.63 / 1.38 (p. 4) | **20 × 45 mm board, 1.2 mm**, 6 × 6 mm corner (p. 3–4) | **series 6.8 nH** at the antenna; second series spot "−" (p. 3) |
| YAGEO ANT3216LL00R2400A (C293767) | 3.2 × 1.6 × 1.2 (p. 3) | 2.4–2.5 GHz, BW 160 MHz (p. 3) | peak 5.05 dBi, MEG 0.45 dBi, **efficiency 70.7 % (−1.50 dB)** (p. 5) | −27.3 dB at 2.45 GHz, −10 dB at 2.37 and 2.53 GHz (p. 5) | 30 × 18 mm ground + 10 × 18 mm clearance (p. 4) | pi footprint drawn, values not given (p. 4) |
| Walsin RFANT5220110A0T (C127611) | 5.2 × 2.0 × 1.15 (p. 2) | 2.4–2.5 GHz (p. 3) | 2 dBi typ.; peak 2.66 dBi; plane averages −0.82 / −0.91 / −0.68 dBi, mean ≈ −0.8 dBi (computed); no efficiency (p. 5) | VSWR 2 max. (p. 3); −13.3 / −16.1 / −15.3 dB at 2.40 / 2.45 / 2.50 GHz, BW > 150 MHz (p. 4) | 30 × 18 mm ground + 18 × 9 mm clearance, 0.8 mm (p. 4) | none, direct feed (p. 3) |
| Kinghelm KH5220-A36 (C484543) | 5.2 × 2.0 × 1.2 (p. 4) | 2450 MHz, BW 100 MHz typ. (p. 6) | peak 4.97 dBi, avg. −0.79 dBi, **efficiency 70.2 / 71.1 / 71.2 %** at 2.40 / 2.45 / 2.50 GHz (p. 8) | VSWR ≤ 2.0 (p. 6); −28.2 dB at 2.45 GHz, −10.2 dB at 2.370 and 2.538 GHz (p. 6) | **90 × 50 mm**, antenna in a corner (p. 5, 7) | series 4.3 nH, then 1.5 pF shunt on the radio side (p. 5) |
| microgate MGMA5220H2450-A04 (C486321) | 5.2 × 2.0 × 1.15 (p. 3) | 2450 ± 75 MHz (p. 4) | 0–2 dBi; patterns without numbers; no efficiency (p. 4–5) | VSWR ≤ 2.0 in band; S11 minimum about −24 dB, BW ≥ 150 MHz (p. 4) | 39 × 18 mm board, 30 × 18 mm ground (p. 3) | not given; "tune to 2.45 GHz with a matching circuit on the application PCB" (p. 4) |

The plane averages are the printed per-cut averages (vertical and horizontal combined). Their mean is only a rough
stand-in for efficiency; YAGEO shows the gap (MEG +0.45 dBi against an efficiency of −1.5 dB).

## Layout

| Part | Copper-free area and position (eval board) | Lands | Pin 1 / pin 2 | Corner on a small board? | Stock, price |
|---|---|---|---|---|---|
| RFECA3216060A1T, Walsin | 8.0 × 3.0 mm notch in the middle of a long edge; "the limited size … is L > 30 mm and D > 6 mm": more than 30 mm of ground along the edge and more than 6 mm between the notch and the board corner (p. 3) | pin 2: land 0.35 × 1.6 at the end of a 1.8 × 1.6 pad; pin 1: split in FEED 0.35 × 0.65 and GND 0.35 × 0.65 with a 0.3 slot; 2.6 mm between lands (8.0 − 0.3 − 0.6 − 1.8 − 2.7, computed), pitch ≈ 2.95 (p. 3; dimensions legible in C411566 p. 2) | pin 1 = feed and GND (the lower half joins the ground beside it); pin 2 → 0402 → GND | **No**: the datasheet rules out a corner (D > 6) and our edge is 29 mm (L > 30) | 32,473, $0.056 |
| RFECA3216060A1T, Kinghelm | type 1: 8.0 × 3.0 mm, type 2: 6.3 × 4.0 mm, both mid-edge, same L > 30 / D > 6 (p. 2–3) | as Walsin; in type 2 the pin-1 GND land reaches the ground 1.0 mm away (p. 3) | as Walsin | **No** | 8,057, $0.079 |
| RFANT3216120A5T | **6 × 6 mm in a board corner**, antenna along the edge, fed from the ground side along the edge (p. 3) | 0.8 × 1.66, 2.3 mm gap, pitch 3.1 (p. 3) | terminal 1 feed (through 6.8 nH); terminal 3 an isolated pad, **open** | **Yes** (20 × 45 mm) | 3,773, $0.117 |
| ANT3216LL00R2400A | 10 mm × full width (18 mm) at the board end; antenna on the feed axis pointing away from the ground, its feed land 2.0 mm out from the ground edge (p. 4) | 0.4 × 1.8, 3.5 mm outer (pitch 3.1) (p. 4) | S1 feed; S2 continues as an open stub 1.8 wide, 2.5 long (p. 4) | No: needs a 10 mm-deep strip across the board end | 18,305, $0.189 |
| RFANT5220110A0T | 9 mm × full width (18 mm) at the board end; antenna perpendicular to the ground edge, feed land 1.0 mm from the ground (p. 3–4) | 2.0 × 1.0, 4.4 mm gap, pitch 5.4 (p. 3) | feed; soldering terminal with an L-shaped open stub toward the board edge (drawn 2.5 and 3.3 mm) (p. 3) | No: about 9–10 mm deep, full width | 31,802, $0.259 |
| KH5220-A36 | **8.5 × 6.3 mm in a board corner**: antenna along the edge, lands 0.3 mm from both board edges, feed land 2.0 mm from the ground on the side, 4.0 mm of clearance between the lands and the ground below (p. 5) | 1.0 × 2.0, 4.2 mm gap, pitch 5.2 (p. 5) | ① input; ② NC, **open** (p. 4) | Corner yes, but on a 90 × 50 mm board | 6,566, $0.232 |
| MGMA5220H2450-A04 | 9 mm × full width (18 mm) at the board end; antenna perpendicular to the ground edge, feed land at the ground edge (p. 3) | 1.8 × 0.8, 4.6 mm gap, pitch 5.4 (p. 3) | ① feed; ② soldering terminal, enlarged on the test board to an L-shaped pad (2.8 × 1.8 plus 1.5 × 1.5) (p. 3) | No: end strip | 2,288, $0.139 |

Only two parts are drawn in a corner: RFANT3216120A5T (6 × 6 mm, small board) and KH5220-A36 (8.5 × 6.3 mm, large
board). YAGEO, RFANT5220110A0T and microgate need a 9–10 mm clearance strip across the whole end of the board. The
RFECA parts need a mid-edge notch at least 6 mm from the corner.

Note on the part currently on the board: besides ruling out the corner, the RFECA layout is not a plain two-pad
footprint (split FEED/GND land on pin 1, 0402 from pin 2 to ground). The current footprint
(`lib/herz_badge.pretty/ANT_Walsin_RFECA3216060A1T.kicad_mod`: 1206 lands, pad 2 open) does not follow it.

## Recommendation: Walsin RFANT3216120A5T (LCSC C127629)

1. **Fits the corner.** Its reference keep-out is 6 × 6 mm in a board corner (p. 3). That fits inside the current
   8.2 × 6 mm area and can be copied exactly.
2. **Measured on a board like ours.** It is the only candidate measured in a corner on a small board:
   20 × 45 mm, about 860 mm² of ground, against our 29 × 34 mm and about 950 mm². On that board S11 is −12 dB or
   better from 2.40 to 2.50 GHz (p. 4). The plane averages are +0.9 / −1.9 / −2.6 dBi (p. 5). There is no efficiency
   figure. KH5220-A36 (71 %) and YAGEO (71 %) have better-documented efficiency, but KH5220-A36 was measured on a
   90 × 50 mm board (nearly five times our ground area) and YAGEO needs a full-width end strip.
3. **A layout we can copy.** The layout is fully dimensioned and has a single matching value: 6.8 nH in series at the
   antenna (p. 3).
4. **Stock and price.** 3,773 in stock covers 1,000 boards plus attrition but not much more, so reserve the reel
   before ordering. At $0.117 it costs half as much as the 5.2 mm parts.

Its weak points: the antenna resonates at 2.9 GHz without matching (p. 3), so the series inductor does the tuning and
must sit at the antenna, not at the chip. The eval board is 1.2 mm thick and our thickness is still open
(PRODUCTION.md). Ordering 1.2 mm keeps one more variable equal to the reference.

**Runner-up: Kinghelm KH5220-A36 (C484543).** Its corner layout (8.5 × 6.3 mm, p. 5) is almost our keep-out. It has
the best efficiency data (71 %, p. 8), a stated match (series 4.3 nH, shunt 1.5 pF, p. 5), 6,566 in stock and pin 2
NC. Against it: it was measured on a 90 × 50 mm board, so neither the match nor the efficiency transfers directly.
It costs $0.232. Its pin-2 land sits 0.3 mm from both edges, which puts its corner on our 1.0 mm corner radius, so
it would have to move in about 0.5 mm.

### Land pattern (p. 2–3)

Walsin numbers the terminals 1 = feeding, 2 = identification mark (no pad), 3 = soldering terminal (p. 2). In the
footprint below, pad 2 is Walsin terminal 3. The part's long axis is along X and the origin is the part centre.

| Pad | Walsin terminal | Size X × Y, mm | Centre, mm | Connects to |
|---|---|---|---|---|
| 1 | 1, feeding | 0.80 × 1.66 | (−1.55, 0) | RF feed through the series inductor |
| 2 | 3, soldering terminal | 0.80 × 1.66 | (+1.55, 0) | nothing: an isolated pad in the keep-out (open) |

The gap between the lands is 2.30 mm, the outer extent 3.90 mm and the pitch 3.10 mm. The 2.3 gap, the terminal-3
land of 0.8 × 1.66 and the 6 / 1.66 / 3.43 heights are dimensioned. The feed land is drawn the same size; the 1.63 mm
dimension covers its stem and land together (0.83 + 0.80). The body is 3.2 × 1.6 mm with 0.25 mm terminations (p. 2).

The feed land continues toward the ground as a 0.8 mm wide stem, 0.83 mm long. Next comes the "Series 1" gap of
0.36 mm (6.8 nH), then a 1.88 mm feed pad: 0.52 mm of it inside the empty area, 1.36 mm over the ground side. Then
comes the "Series 2" gap of 0.34 mm (value "−", so 0 Ω or plain trace) and the 50 Ω line (p. 3).

### Keep-out as drawn (p. 3)

The empty area is 6.0 × 6.0 mm in the corner of the 20 × 45 mm board, here the top-right corner. Two sides are board
edges and two sides are ground. Rows of ground vias run along both ground sides and both sides of the feed line.
The antenna lies along the edge it sits on (the 20 mm edge), fed from the ground side:

- The lands' outer edge is 0.91 mm from that board edge (6 − 1.66 − 3.43). The land centre line is 1.74 mm from the
  edge. There are 3.43 mm of clearance between the lands and the ground on the far side.
- Along the edge, measured from the ground edge on the feed side: the feed land runs 1.71–2.51 mm and the
  terminal-3 land 4.81–5.61 mm. That leaves 0.39 mm from the terminal-3 land to the side board edge (from the chain
  0.52 + 0.36 + 1.63 + 2.3 + 0.8 inside the 6.0).

Mapped onto the badge (top view, origin top-left, board 29 × 34; the antenna is on the back, so seen from the back
the picture is mirrored): along the bottom edge, fed from the right.

| Item | Position, mm |
|---|---|
| Keep-out, all layers | x 0–6.00, y 28.00–34.00 (smaller than today's 8.2 mm; ground may return to x 6.0–8.2) |
| Antenna centre | (2.34, 32.26) |
| Pad 2 (open), centre | (0.79, 32.26); its corner stays about 0.38 mm inside the 1.0 mm corner radius |
| Pad 1 (feed), centre | (3.89, 32.26) |
| Series 6.8 nH (0402), centre | about (5.30, 32.26), inside the keep-out next to the feed land |
| Feed line | enters the keep-out at x = 6.00 on y = 32.26 and comes from U201 outside the keep-out |

The 6.8 nH sits inside the keep-out, so the rule area has to allow that one part. The current
`place_badge.py` keep-out says "no other parts".

### Starting matching values (p. 3)

- Series at the antenna ("Series 1"): **6.8 nH**, 0402, an RF multilayer type such as the MLG1005S or SDCL1005
  families already in the BOM (6N8 value, stock not checked).
- Second series spot ("Series 2", "−"): 0 Ω or plain trace. R207 stays 0 Ω.
- Shunts: none on the eval board, so C213 and C215 are not fitted.
- If the badge comes out off-frequency, the inductor is the knob. More inductance lowers the frequency (8.2 nH);
  less raises it (5.6 nH).
