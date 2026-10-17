# BOM

Status (2026-10-17): badge parts cost from bomi's LCSC price breaks after the datasheet review (DESIGN.md D12–D16),
plus the cell; reference board below it.

# Badge (`boards/badge/`)

## Source and scope

`cd boards/badge && bomi import kicad badge.kicad_pro --replace && bomi list --check`, then `python3
scripts/bom_cost.py boards/badge` for the table: each part bought at the LCSC price break its total quantity
reaches. 36 lines, 35 distinct parts, 137 placements; the five test pads and the two open RF shunts (C213, C215)
are not assembled. PCB, assembly, stencils and setup come from JLC's quote (PRODUCTION.md); the cell is bought
separately.

| Boards | 1 | 10 | 100 | 500 | 1000 |
| --- | --- | --- | --- | --- | --- |
| Parts per board | $12.35 | $10.55 | $8.91 | $8.14 | $7.96 |
| Extended-part fees per board (17 × about $3 per order) | $51.00 | $5.10 | $0.51 | $0.10 | $0.05 |
| LiPo cell, 103030 1000 mAh (Alibaba, CHF, before shipping) | 1.06–1.19 | 0.84–1.09 | 0.68–0.85 | 0.68–0.85 | 0.68–0.85 |

The cell prices are the listings found on 2026-10-17 (Huizhou Jiaxinrui, Shenzhen WLY, Dongguan Mozhong; minimum
orders 1–5). Ask for a protection board, a JST PH 2.0 plug with pin 2 = +, and the real capacity; lithium cells
ship as dangerous goods, which can cost more than the cells on small orders.

## Cost drivers

| Part | LCSC | Refs | Qty | 100 boards | 1000 boards | Stock |
| --- | --- | --- | --- | --- | --- | --- |
| WS2812B-2020-V6 | C52917434 | D301–D364 | 64 | $3.35 | $3.35 | 932,124 |
| ESP32-S3FH4R2 | C3013940 | U201 | 1 | $2.57 | $2.37 | 3,838 |
| QMI8658A | C3021082 | U202 | 1 | $1.39 | $1.00 | 13,088 |
| AO3401A | C15127 | Q101–Q103 | 3 | $0.22 | $0.18 | 699,695 |
| JST S2B-PH-SM4-TB | C295747 | J102 | 1 | $0.18 | $0.14 | 36,072 |
| TYPE-C-31-M-12 | C165948 | J101 | 1 | $0.15 | $0.10 | 365,715 |
| USBLC6-2SC6 (ST) | C7519 | U103 | 1 | $0.14 | $0.10 | 34,844 |
| RFANT3216120A5T | C127629 | AE201 | 1 | $0.10 | $0.09 | 3,773 |
| TP4056 (UMW) | C725790 | U101 | 1 | $0.07 | $0.06 | 251,734 |

The LEDs, the ESP32-S3 and the IMU are 82 % of the parts cost at 100 boards. Leaving the IMU off (no firmware uses
it yet) saves $1.39 per board at 100 and $1.00 at 1000, plus one Extended fee. The full table is the output of
`scripts/bom_cost.py`.

## Extended parts

ESP32-S3FH4R2, LQG15HS6N8J02D (6.8 nH), ME6217C33M5G, MLG1005S2N0BT000 (2 nH), MSK12C02, QMI8658A, RFANT3216120A5T,
S2B-PH-SM4-TB, the 40 MHz crystal, SDCL1005C24NJTDF (24 nH), SN74LVC1T45DBVR, SS14L, TP4056, TS-1088R-02026,
TYPE-C-31-M-12, USBLC6-2SC6, WS2812B-2020-V6. The B5819WS (C64886, D104) is a Preferred part, without the fee.

## Stock risks

| Part | Stock (2026-10-17) | Note |
| --- | --- | --- |
| RFANT3216120A5T | 3,773 | enough for about 1000 boards; reserve before ordering. Runner-up Kinghelm KH5220-A36 C484543 needs a new footprint and keep-out (docs/datasheets/antennas.md) |
| ESP32-S3FH4R2 | 3,838 | enough for 1000 boards; ESP32-S3-MINI-1-N4R2 is the fallback (a layout change) |
| 40 MHz crystal C426988 | 2,390 | any 3225 40 MHz with a 10 pF load fits the same footprint |

# Reference board (`boards/reference/`)

## Source and scope

`cd boards/reference && bomi import kicad reference.kicad_pro && bomi status`, from the generated reference
schematic. Excluded: the PCB, assembly fees, the antenna J2, header P1 and pads TP1–TP3 (no LCSC part). Parts
stand in for the vendor's where the vendor's are not stocked (LEDs, IMU) or not identified (USB-C, buttons,
crystal size); the notes on each symbol say which.

**$11.79 per board at single-unit prices**, 35 BOM lines, 13 Extended parts (JLC's Extended-part fee, about $3 each,
is charged per unique part per order, so about $39 per order).

## Cost drivers

| Part | LCSC | Refs | Qty | Unit (1) | Per board | Note |
| --- | --- | --- | --- | --- | --- | --- |
| WS2812B-2020-V6 | C52917434 | U1–U48, U50–U65 | 64 | $0.0913 | $5.84 | $0.0523 from 4,500 pcs, so about $3.35 per board at 100 boards |
| ESP32-S3FH4R2 | C3013940 | U66 | 1 | $3.67 | $3.67 | |
| QMI8658C | C2842151 | U67 | 1 | $1.45 | $1.45 | out of stock; the QMI8658A (C3021082) is $1.98 |
| TYPE-C-31-M-12 | C165948 | J1 | 1 | $0.19 | $0.19 | stand-in for the unidentified vendor part |
| TS-1088R-02026 | C455280 | Key1, Key2 | 2 | $0.056 | $0.11 | |
| ME6217C33M5G | C427602 | U49 | 1 | $0.106 | $0.11 | |
| DMG1012T-7 | C20512 | Q1 | 1 | $0.101 | $0.10 | |
| 40 MHz 3225 crystal | C426988 | Y1 | 1 | $0.075 | $0.08 | |

Everything else together is under $0.25.

## Extended parts

D1, IND1, L1, Q1, R5, R6, the LEDs, U49, U66, U67, Y1, J1, Key1/Key2. Cheap swaps for the clone: R6 499 Ω to the
Basic 470 Ω (C25117), D1 B5819WS to the Basic B5819W SL (C8598, SOD-123), Q1 replaced by the SN74LVC1T45 anyway
(DESIGN.md section 4).

## Stock risks

| Part | Stock | Substitute | Circuit change |
| --- | --- | --- | --- |
| QMI8658C | 0 | QMI8658A C3021082 (13,088) | none: same package and pins |
| 40 MHz crystal C426988 | 2,390 | another 3225 40 MHz, 10 pF load | none if the load capacitance matches |
| ESP32-S3FH4R2 | 3,838 | ESP32-S3-MINI-1-N4R2 C3013941 (3,014) | a module instead of the chip (D6) |
