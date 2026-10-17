# Production

Status (2026-10-17): order files for a JLC quote of the placed, unrouted badge; not for ordering.

How to order, what it costs, and a dated log of quotes and orders (newest first).

## Order files

`scripts/make_fab.sh <board>` writes `build/fab/<board>/` (git-ignored; regenerate before each order). It refuses a
board that fails DRC, which an unrouted board does (its nets are unconnected), so the quote files come straight from
`pcbkit fab boards/badge/badge.kicad_pcb build/fab/badge`: `GERBER-badge.zip`, `BOM-badge-both.csv` and
`CPL-badge-both.csv` (137 placements: the LEDs, the charge LED and its resistor on the front, everything else on the
back; the five test pads and the two open RF shunts are left out).

## Getting a quote at JLC (unrouted board)

1. Upload `GERBER-badge.zip`. Check: 4 layers, 30 × 34 mm. Choose the quantity, 1.2 mm (the thickness of the
   antenna's reference board, DESIGN.md D15) and ENIG (the QFN's 0.4 mm pitch and the IMU's LGA want a flat finish).
   The board has no tracks yet, which does not change the price; do not order it.
2. Turn on PCB Assembly, both sides (JLC may require Standard rather than Economic assembly for two sides).
3. Upload `BOM-badge-both.csv` and `CPL-badge-both.csv`; check that every line matched its LCSC part and that the
   preview shows the LEDs' pin 1 consistently, the USB-C mouth at the bottom edge and the JST mouth at the right edge.
4. The quote's part cost should land near BOM.md's table ($8.91 per board at 100); the rest is PCB, setup, stencils,
   Extended-part fees (17 parts, about $51 per order) and joints.
5. Before a real order: reserve the antenna (3,773 in stock) and recheck the ESP32-S3FH4R2 and crystal stock.

## Order checklist

- PCB: layers, thickness, stackup, panel settings.
- Assembly: service, side(s); the BOM page must say "Your BOM: JLCPCB Part #".
- Placement preview: polarity and rotation of <parts that have bitten before>.

## Costs
