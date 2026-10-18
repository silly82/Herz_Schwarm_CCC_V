# Homelib follow-up: badge battery precedents and a check of the homelib write-ups
Source: the badge-batteries topic in the user's homelib library (58 items), its three LLM research write-ups (badge precedents, chemistry and form factor, pouch-cell integration), the topic synthesis, and the primary sources they cite or should have cited; gathered 2026-10-18

Scope note. The three homelib write-ups and the topic synthesis are LLM-generated. Most of their text is generic advice. The badge write-up found almost no badge facts beyond flow3r's spec page, so section 1 was researched from scratch in the badges' own docs, schematics, BOMs and firmware. Every decision-relevant claim was re-checked against a primary source: those badge files, Battery University, datasheets, IATA, EUR-Lex and this repo. Anything not tied to a primary source is marked **unverified**. Errors found, besides the known one (the chemistry write-up says a 103030 "usually fails" 5–8 h and that the badge needs a 5 V boost):
- **Chemistry write-up:**
  - It puts a WS2812 pixel at "approximately 60 mA" full white. The V6 draws 36 mA.
  - Its 1.5–3 Ah capacity target and its "about 2 A from the battery" peak both include a boost converter that the badge does not have.
  - It says 1–2 Ah "cannot realistically fit" in 30 × 34 mm. A 103030 does fit.
  - It says primary lithium AA/AAA cells "can exceed 3.3 V when fresh". They are 1.5 V cells.
  - It cites BU-205 for LFP cycle life but quotes BU-216's numbers.
  - It rejects LiFePO4 because of the ESP32. The real blocker is the LEDs' 3.3 V minimum.
- **Badge write-up:**
  - It reads "505060" as about 50 × 50 × 6 mm. It is 5.0 × 50 × 60 mm.
  - It calls 500–1,000 mAh "a reasonable starting point". A 600 mAh cell gives 3.6 h at this badge's load.
- **Pouch write-up:** no wrong numbers. But it leaves out two numbers that matter:
  - the IATA 30 % state-of-charge limit, which since 1 January 2026 also covers cells over 2.7 Wh packed with equipment;
  - Battery University's 8–10 % swelling allowance.
- **Topic synthesis:**
  - "30 × 34 mm forces a 400–600 mAh pouch" is wrong, and so is "1.2 A demands ≥2C".
  - "LiFePO4 can feed the rail directly" is false with these LEDs.
  - "Unprotected 18650s deliver hundreds of amps" is not in the source it cites.
  - The epoxy "of traces" was on the boards and solder joints.
  - The EMF battery mount is called "serviceable", but it is glued.
  - Its runtime arithmetic does not add up.
- **This repo:** DESIGN.md section 5 says "store and ship at about 40–60 % charge". That is right for storage. But cells shipped by air must be at 30 % or less (section 4).

The Asia supplier note in this folder ([suppliers_asia.md](suppliers_asia.md), Q1) found that real 103030 cells hold 800–900 mAh, not 1000 mAh. The verdict in section 6 uses 850 mAh as well as 1000 mAh. Runtime scales with capacity.

## 1. Badge precedents: what earlier badges used, and how they held and protected the cell

### Takeaway
Of 21 badges, 15 ran on one lithium cell. WHY2025 used two 18650s in parallel, four badges used AA cells, and DEF CON 32's Li-ion setup is not documented.

**Attachment.**
- Pouch cells were held by glue dots (card10, flow3r, Tildagon), velcro (MCH2022) or a cover (Fri3d 2024, and flow3r's screwed metal cover).
- Cylindrical cells sat in spring holders (WHY2025, Fri3d 2022, and the AA badges).

**Protection.** The badges whose source says so used protected cells: SHA2017, MCH2022, Fri3d 2024. Fri3d 2022 instead put a DW01-P and FS8205A on the board next to its 18650 holder. TiLDA Mk3 had a footprint for an on-board protector but left it unfitted. The one badge that handed out unprotected cells, WHY2025, was publicly declared a fire hazard during the event.

**Connectors.** JST PH 2.0 dominates (TiLDA Mk3 and Mk4, Tildagon, Supercon 2025, BornHack 2026). MCH2022 and flow3r shared a keyed 1.5 mm JST ZH. Three early badges (r0ket, SHA2017, rad1o) used a 3-pin JST PH, with the third pin to the charger's NTC input. BornHack 2024 used an unkeyed 2.54 mm pin header.

**Charge current.** It ranged from 90 mA (card10, 200 mAh) to about 1.5 A (Tildagon, 2000 mAh). Where both current and capacity are known it is 0.25–1C. SHA2017's 1 A into 1000 mAh is the 1C end.

**Lessons for removability.** EMF's own Tildagon guide needs adhesive remover or 99 % isopropyl to get the cell off its "very strong glue dots". EU Art. 11 excludes removal that needs "solvents" (section 4). Two precedents fit that rule best:
- MCH2022: velcro plus a keyed plug;
- flow3r: a plug plus a cover screwed on with a supplied Allen key, though the cell is also glued to the cover.

**Lesson on crushing.** EMF raised the 2026 board spacing by 1 mm "to avoid battery squishing". That is the same hazard this badge's D19 spacer addresses.

**Reuse.** Cells were reused across events. flow3r takes MCH2022's battery. The Tildagon takes the batteries from the 2016 and 2018 EMF badges.

Few runtime claims exist. r0ket and SHA2017 promise "at least a day", BornHack 2026 aims for a week, and flow3r gives only a 1.1 A worst-case draw. Apart from WHY2025, no badge source reports a battery incident. Tildagon's spacing change is the nearest thing.

### Cited findings
| Badge | Cell | Connector | Mounting | Protection | Charger, charge current | Supplied? | Runtime claim | Incidents, advisories |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| r0ket, Camp 2011 | LiPo, 3.7 V 600 mAh, "custom made" | JST PH 3-pin footprint in schematic (my reading) | not documented | not documented | MCP73833 named in schematic | listed as part of the hardware | 600 mAh "powers a backlight for at least one day" | not documented |
| rad1o, Camp 2015 | "slim, rechargeable LiPo", capacity not documented | 3-pin JST PH, third pin to charger THM | "mounted on the back" | not documented | MAX8934 (power path) | not documented | not documented | LED switch-off FETs did not work: unplug the battery to switch off, else 0.5 mA standby |
| card10, Camp 2019 | 200 mAh (prototypes 100–150 mAh) | plug, type not documented | a glue dot on the harmonic board | not documented | MAX77650 PMIC, 90 mA, 4.2 V, 190 mA USB limit | yes (assembly kit) | not documented | none found |
| flow3r, Camp 2023 | 2000 mAh "505060" | JST ZH 1.5 mm (S2B-ZR-SM4A-TF), as MCH2022 | adhesive dots to the board and to a metal cover, screwed into the PCB stack with a supplied Allen key | none on board: "No undervoltage protection! No auto shutdown!" | BQ24074, 500 mA | optional extra | none; worst case "up to 1.1 A" | schematic warns: unplug for storage; "no proper thermal sensing" |
| SHA2017 | LiPo 1000 mAh, protected pouch | JST PH 3-pin with TEMP line | not documented | on the cell; 1 A PTC at charger and at USB | TP4056, R_PROG 1.2 kΩ (1 A) | yes | "at least a day when used interactively" | none found |
| MCH2022 | LiPo pouch, protected, 2000 mAh per flow3r docs | JST ZH 1.5 mm, keyed lug; pin 1 GND, pin 2 + | supplied self-adhesive velcro | on the cell | XT4054, R_PROG 1 kΩ (about 1 A by the schematic's formula) | yes | not documented | none found |
| WHY2025 | 2 × 18650 in parallel, unprotected (LG) | two soldered spring holders | holders | none on the cells; polyfuses and a power-bank IC on the board | power-bank IC (not named) | yes | not documented | fire-hazard advisory; organisers added epoxy and a leaflet |
| TiLDA Mk3, EMF 2016 | LiPo, capacity not documented | JST PH 2 mm | not documented | BQ2970 protector footprint left unfitted (0 Ω bypass) | BQ24092, 1 kΩ ISET; TS tied to a fixed 10 kΩ | not documented | not documented | not documented |
| TiLDA Mk4, EMF 2018 | LiPo "2000mAh" (docs); schematic outline says "1000mAh JST-PH", 32 × 50 mm | JST PH S2B-PH-SM4-TB | not documented | not documented | BQ25601 | yes (listed hardware) | not documented | not documented |
| Tildagon, EMF 2024 | 2000 mAh 3.7 V LiPo, max 64 × 40 × 7 mm | JST PH (B2B-PH-SM4-TB) | "very strong glue dots", between the boards | not documented | BQ25895, up to 1.5 A (0.77C) | yes (kit) | not documented | 2026 standoffs raised to 11 mm "to avoid battery squishing" |
| Tildagon 2026, EMF 2026 | 1800 mAh | as 2024 | glue dots; removal with isopropyl at the badge tent | not documented | BQ25895, 0.85C | yes; spare £2.50 | not documented | as above |
| Fri3d 2022 | one 18650 | spring holder | holder | on the board: DW01-P + FS8205A | TP4056; notes for 0.13/0.5/1 A | not documented | not documented | none found |
| Fri3d 2024 | LiPo 704060 2000 mAh, "built-in protection circuit" | JST | under a protective PCB cover | on the cell | TP4056, NTC on TEMP | yes | not documented | none found |
| BornHack 2024 | 1S LiPo, capacity not documented | 2.54 mm 1 × 2 pin header (unkeyed) | on the rear | none on board | HX4054A (TP4054 class), 2 kΩ R_PROG | not documented | not documented | none found |
| BornHack 2025 | 2 × AA | two AA holders | holders under a snap-on back case | — | none (QX2304 boost) | not documented | not documented | none found |
| BornHack 2026 | "LiPo" / "Li-ion" (docs disagree), capacity not documented | PH-2AWB 2-pin (2.0 mm) | not documented | not documented | XT4054, 0.5 A | not documented | goal: one week | none found |
| Supercon 2023 | 2 × AA | two Keystone 2460 holders | holders | — | none | not documented | not documented | none found |
| Supercon 2024 | AA | two Keystone 2460 footprints (third-party redraw) | holders | — | none; pads for an external supply | not documented | not documented | none found |
| Supercon 2025 | LiPo, capacity not documented | JST PH S2B-PH-SM4-TB | not documented | not documented | MCP73831, 500 mA; PFET power path | not documented | not documented | none found |
| DEF CON 26 | 4 × AA | "nested into two holders" | holders | — | none | not documented | not documented | none found |
| DEF CON 32 | "rechargeable li-ion battery" | not documented | not documented | not documented | not documented | not documented | not documented | none found |

**CCC camps**
- r0ket:
  - "Custom made 3.7V 600mAh rechargeable LiPo battery" — [r0ket wiki, hardware](https://r0ket.badge.events.ccc.de/hardware).
  - The concept page promises a "High capacity lithium-polymer battery, rechargeable via USB" and complains that older badges left "heaps of empty batteries" — [concept](https://r0ket.badge.events.ccc.de/concept).
  - The Camp 2011 talk says a 600 mAh battery "powers a backlight for at least one day", with a charge controller that works without the firmware — [hardware.tex](https://github.com/r0ket/r0ket/blob/master/doku/vortrag/hardware.tex).
  - The binary Eagle schematic names MCP73833, MCP1700 and a JST-PH3 part (from its embedded strings; my reading) — [r0ket.sch](https://github.com/r0ket/r0ket/blob/master/hardware/r0ket/r0ket.sch).
- rad1o:
  - The charger is a MAX8934 on net BAT+. A 3-pin JST PH (X801) carries the battery, with its third pin on the charger's THM input — [rad1o.sch](https://github.com/rad1o/hardware/blob/master/rad1o.sch).
  - "Both [micro USB ports] can charge the battery" — [hardware overview](https://rad1o.badge.events.ccc.de/hardware/overview.html).
  - The battery is "mounted on the back" — [Great Scott Gadgets](https://greatscottgadgets.com/2015/08-11-my-first-look-at-rad1o-badge/).
  - The LED power-off transistors did not work. The fix is to "disconnect the battery to power off the badge", because otherwise the LEDs draw 0.5 mA in standby — [issues](https://rad1o.badge.events.ccc.de/issues).
- card10:
  - The battery is "200 mAh (prototypes: 100-150 mAh)", above the fundamental board — [hardware](https://card10.badge.events.ccc.de/hardware/).
  - The assembly guide says "use the glue dot to attach the battery to the harmonic board" — [assembly](https://card10.badge.events.ccc.de/userguide/assembly/).
  - The MAX77650 is set to a 4.2 V target, 90 mA fast charge and a 190 mA USB limit — [pmic.c](https://git.card10.badge.events.ccc.de/card10/firmware/-/blob/master/lib/card10/pmic.c).
- flow3r:
  - "2000mAh battery (505060), compatible with MCH2022 badge" — [hardware specs](https://docs.flow3r.garden/v1.4.0/badge/hardware_specs.html).
  - "The battery is optional this time, and its connector is compatible with the MCH2022 Badge battery". The badge was a €32 add-on for about half of the tickets — [CCC event blog](https://events.ccc.de/en/2023/06/05/camp23-the-flow3r-badge/).
  - The bottom-board schematic: BQ24074 charger, the battery on a JST S2B-ZR-SM4A-TF. Its notes, in my summary:
    - no undervoltage protection and no automatic shutdown on the board;
    - unplug the battery for long storage;
    - don't use cells under 1 Ah, because of the 500 mA charge current;
    - the discharge path is "practically not current limited", and 1C is what most Li+ cells can manage;
    - there is "no proper thermal sensing";
    - the badge can draw "up to 1.1 A" at full volume and brightness;
    - only crude short-circuit protection on +3V3.
    — [bot-schematic.pdf](https://git.flow3r.garden/flow3r/flow3r-hardware/-/blob/main/boards/bot/bot-schematic.pdf).
  - The assembly guide: the cell plugs in, and its cable runs through a notch. Round adhesive pieces glue it to the board and to a metal battery cover. Five screws, tightened with the supplied Allen wrench, hold the stack together — [assembly](https://docs.flow3r.garden/badge/assembly.html).

**Dutch camps (SHA2017, MCH2022, WHY2025)**
- SHA2017:
  - "a 1000mAh lithium-polymer cell" on the rear — [Hackaday, 14 Aug 2017](https://hackaday.com/2017/08/14/hands-on-with-the-shacamp-2017-badge/).
  - The battery "should be able to last for at least a day when used interactively" — [SHA2017 wiki](https://wiki.sha2017.org/w/Projects:Badge).
  - The final schematic (rev 1.0.1) has:
    - a TP4056 with R_PROG 1.2 kΩ, which is 1 A by the TP4056 formula;
    - a 10 kΩ from VCC to TEMP, with TEMP also on the 3-pin JST PH;
    - a 1 A PTC (F2) between the charger's BAT pin and VBAT, and another (F1) on USB 5 V
    — [sha2017_rev1_0_1.sch](https://github.com/SHA2017-badge/PCB/blob/master/sha2017_rev1_0_1.sch).
- MCH2022:
  - The kit contained "a lithium-polymer battery" and "a self-adhesive Velcro patch". The trailing plug "has a small lug" that fits a notch, and "the connector only allows it to be connected the right way around". The guide also notes that one side of the battery bulges, so users should find the side that lies flattest — [getting started](https://badge.team/docs/badges/mch2022/getting-started/).
  - The connector is a JST S2B-ZR-SM4A-TF at 1.5 mm pitch, pin 1 GND (black) and pin 2 Vbatt (red) — [battery page](https://badge.team/docs/badges/mch2022/hardware/battery/).
  - The charger is an XT4054K421MR-G with 1 kΩ on PROG. The sheet notes "IBAT = (VPROG / RPROG) * 1000, VPROG = 1V", so about 1 A by its own formula — [power.kicad_sch](https://github.com/badgeteam/mch2022-badge-hardware/blob/master/power.kicad_sch).
- WHY2025 advisory — [wiki.why2025.org/Badge/Fire_hazard](https://wiki.why2025.org/Badge/Fire_hazard):
  - The two parallel 18650s handed out were unprotected. They are printed with the maker's warning that consumers must never carry, use or install them.
  - Protected 18650s are slightly longer and do not fit the holders.
  - The holder tabs were larger than their pads, and the battery traces were 0.4 mm from ground under 10–30 µm of solder mask.
  - In a test with a 20 A supply the protection took too long, and a MOSFET glowed yellow.
  - "The cells can provide more than that".
  - Compared with earlier badges: SHA2017 and MCH2022 also had no housing, but came with protected cells insulated by two layers of kapton tape, about 120 µm.
- WHY2025 response and fixes:
  - Hackaday: the organisers responded "with a printed disclaimer leaflet" and "added a last-minute epoxy coating to the boards" — [Hackaday, 12 Aug 2025](https://hackaday.com/2025/08/12/when-a-badge-misses-the-mark-why-2025/).
  - Peetz0r lists, under "Recommended hardware mods": "Remove the unused 18650 holders" and "Replace them with 1 or 2 protected pouch cells" (a 104050) — [peetz0r.nl/badge](https://peetz0r.nl/badge).

**EMF Camp (TiLDA Mk3, Mk4, Tildagon)**
- TiLDA Mk3 (2016), schematic:
  - a BQ24092 with ISET 1 kΩ and TS on a fixed 10 kΩ, so no cell temperature sensing;
  - the battery on a JST PH 2 mm (JP3);
  - a BQ2970 protector and CSD85301Q2 FET drawn but marked DNP, with a 0 Ω (R32) in the cell's negative lead
  — [Mk3 v3.1415926535.sch](https://github.com/emfcamp/Mk3-Hardware).
- TiLDA Mk4 (2018), "Mk4 Final a.sch":
  - the battery on a JST S2B-PH-SM4-TB;
  - a BQ25601 charger;
  - a 32 × 50 mm battery outline labelled "1000mAh JST-PH"
  — [Mk4-Hardware](https://github.com/emfcamp/Mk4-Hardware).
  - The docs list a "2000mAh Battery" and say the BQ25601 "takes care of charging the LiPo battery" — [Mk4 index](https://github.com/emfcamp/badge-website/blob/main/docs/TiLDA_MK4/index.md), [Mk4 sensors API](https://github.com/emfcamp/badge-website/blob/main/docs/TiLDA_MK4/API/sensors.md).
- Tildagon (2024, 2026):
  - "The most energy-intensive part of each badge is the battery, so we've made it compatible with the batteries from the 2016 and 2018 badges" — [tildagon.badge.emfcamp.org](https://tildagon.badge.emfcamp.org/).
  - The cell is a "2000mAh 3.7V LiPo Battery", maximum 64 × 40 × 7 mm, and the guide says to check that the connector pinout and colours match — [replacing parts](https://github.com/emfcamp/badge-2024-documentation/blob/main/docs/using-the-badge/replacing-parts.md).
  - Assembly uses "2 glue stickers". The 2026 update raised the standoffs to 11 mm "to avoid battery squishing" — [assembly](https://github.com/emfcamp/badge-2024-documentation/blob/main/docs/using-the-badge/tildagon-assembly.md).
  - The 2024 battery "is glued to the front board using very strong glue dots" and also traps the ribbon cable. Removal needs adhesive remover or 99 % isopropyl, and EMF offered this at the 2026 badge tent — [disassembly](https://github.com/emfcamp/badge-2024-documentation/blob/main/docs/using-the-badge/2024-dissembly-instructions.md), [Spaceagon assembly](https://github.com/emfcamp/badge-2024-documentation/blob/main/docs/using-the-badge/spaceagon-assembly.md).
  - The charger is a BQ25895, its hardware ILIM noted as "260R = 1.5A charge current limit", and the battery sits on a JST B2B-PH-SM4-TB — [usb.kicad_sch](https://github.com/emfcamp/badge-2024-hardware/blob/main/tildagon-base/usb.kicad_sch).
  - The firmware sets a 500 mA input limit and a charge current of "0.85C for the 1800mAh and 0.77C for 2000mAh batteries" — [bq25895.c](https://github.com/emfcamp/badge-2024-software/blob/main/drivers/tildagon_power/bq25895/bq25895.c).
  - In the 2026 shop the complete badge (£22) includes the battery, and a "1800mAh battery" spare costs £2.50 — [EMF badge shop](https://www.emfcamp.org/tickets/badge).

**Fri3d Camp**
- 2022, badge "2020 / 2022": the production power sheet has:
  - an "18650 Battery holder with spring";
  - a DW01-P with FS8205A labelled "BATTERY PROTECTION";
  - a TP4056 with notes for 10 kΩ = 0.13 A, 2.4 kΩ = 0.5 A and 1.2 kΩ = 1 A;
  - a TEMP NTC, "Place in center of battery holder"
  — [Fri3D_2020_Power.SchDoc, rev 03](https://github.com/Fri3dCamp/badge-2020/tree/master/design/Fri3D_2020_03) (my reading of the Altium strings).
- 2024:
  - The README (in Dutch, my translation) describes a 2000 mAh lithium-polymer cell "with a built-in protection circuit". It says these cells are mechanically weaker than the 18650 of the last edition, so the badge has a cover for the battery as standard. Charging is again a TP4056 — [badge_2024_hw](https://github.com/Fri3dCamp/badge_2024_hw), cell [datasheet](https://github.com/Fri3dCamp/badge_2024_hw/blob/main/Datasheets/2000mAh_704060_battery_Tewaycell.pdf).
  - The power sheet adds an NTC divider on TEMP, with design points at 0, 25, 45 and 60 °C, and a JST connector — [Fri3D_2024_Power.SchDoc](https://github.com/Fri3dCamp/badge_2024_hw/tree/main/Fri3d_2024_Badge_01).

**BornHack**
- 2024 and 2025: 2024 has "the electronics and LiPo battery on the rear"; 2025 uses "a pair of AA batteries" — [Hackaday, 1 Aug 2025](https://hackaday.com/2025/08/01/two-for-the-price-of-one-bornhack-2024-and-2025-badges/).
- 2024 power sheet: an HX4054A with 2 kΩ PROG, an AP2112K LDO, and the cell on a 2.54 mm 1 × 2 pin header — [1s_lipo.kicad_sch](https://github.com/bornhack/badge2024/tree/hardware).
- 2025: two BH-AA-A1AJ020 holders, a QX2304 boost converter and an XC6210 LDO — [psu_2xAA_usb_3v3.kicad_sch](https://github.com/bornhack/badge2025). A snap-on half case "covers the back part with the battery holders" — [README](https://github.com/bornhack/badge2025).
- 2026 Cyber Ægg:
  - The power sheet has an XT4054 charging at "IBAT = (1v/2k)*1000 = 0.5A", a TPS63805 buck-boost to 3.3 V and a PH-2AWB battery connector — [power.kicad_sch](https://codeberg.org/Ranzbak/bornhack2026-hardware).
  - The goal is the whole camp "on one battery charge (One week)" — [readme](https://codeberg.org/Ranzbak/bornhack2026-hardware).
  - The docs call the cell "Li-ion" in one table and "LiPo" in the text, and the slide switch cuts battery power — [hardware](https://badge.team/docs/badges/bornhack-2026/hardware/).

**Hackaday Supercon, DEF CON**
- Supercon 2023 (Vectorscope): the BOM lists BH1 and BH2 as "BATT HOLDER AA 1 CELL PC PIN", Keystone 2460 — [Badge2023_BOM_R1.xlsx](https://github.com/Hack-a-Day/Vectorscope/blob/main/hardware/vectorscope/Badge2023_BOM_R1.xlsx).
- Supercon 2024: the reveal mentions "AA battery love" and pads for an external supply — [Hackaday, 22 Oct 2024](https://hackaday.com/2024/10/22/the-2024-hackaday-supercon-sao-badge-reveal/). A third-party KiCad redraw shows two Keystone 2460 1 × AA footprints (secondary) — [supercon24-badge-kicad-redrawn](https://github.com/thestumbler/supercon24-badge-kicad-redrawn).
- Supercon 2025 Communicator: the power sheet has an MCP73831 noted "2 k -> 500 mA", an AP2112K-3.3, and a PFET power path ("VBUS < VBat: PFET conducts, battery drives board") — [Power.kicad_sch](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/hardware/communicator_pcb/Power.kicad_sch). The BOM's J4 is a JST S2B-PH-SM4-TB — [BOM](https://github.com/Hack-a-Day/2025-Communicator_Badge/blob/main/hardware/communicator_pcb/communicator_pcb_BOM.csv). The announcement says only "LiPo and charging circuitry" — [Hackaday, 23 Oct 2025](https://hackaday.com/2025/10/23/announcing-the-2025-hackaday-superconference-communicator-badge/).
- DEF CON 26: "four AA batteries which are nested into two holders" — [Hackaday, 9 Aug 2018](https://hackaday.com/2018/08/09/first-look-at-def-con-26-official-badge/).
- DEF CON 32: the official shop lists "USB-C & rechargeable li-ion battery" and nothing more — [DEF CON shop](https://us.shop.defcon.org/products/dc32-badge). An llmlayer answer claiming AAA cells cited a page that says nothing about batteries (**unverified**, not used).

### Inferences
- The protected pouch on a keyed plug (SHA2017, MCH2022, Fri3d 2024) is the established safe pattern. Herz-Schwarm's D18 (protected cells only) and D5 (JST PH) follow it.
- Glue dots are the common mount but conflict with Art. 11 from 18 Feb 2027 when removal needs solvent. MCH2022's velcro plus keyed plug is the closest precedent to "readily removable". For this badge, velcro or a low-tack removable pad over the D19 foam spacer, plus the JST PH, would meet the rule. An online removal guide is also required (section 4).
- The Communicator puts a PFET beside its MCP73831: the battery drives the board only when VBUS is below VBat. That is the same job as this badge's Q101/D101.
- flow3r's note "no proper thermal sensing" and TiLDA Mk3's fixed TS resistor show that badges often skip the NTC. SHA2017, rad1o and both Fri3d badges kept one. Hazard 3's NTC proposal has precedent.

## 2. Write-up 1 (badge precedents) checked

### Takeaway
The flow3r facts are right, but they are nearly the only badge facts in the write-up. It misreads the 505060 size. It also calls the connector and charger "not specified", although the MCH2022 docs and the flow3r schematic give both. Its "500–1,000 mAh" starting range is too low for this badge's load. Its runtime arithmetic is fine.

### Cited findings
| Claim | Verdict | Primary source |
| --- | --- | --- |
| flow3r: 2000 mAh "505060", compatible with MCH2022 | confirmed | [flow3r hardware specs](https://docs.flow3r.garden/v1.4.0/badge/hardware_specs.html) |
| Battery optional; badge a €32 add-on for about half the tickets | confirmed | [CCC event blog](https://events.ccc.de/en/2023/06/05/camp23-the-flow3r-badge/) |
| "505060 … approximately 50 × 50 × 6 mm" | **wrong**: LiPo codes are thickness (0.1 mm), width, length, so 5.0 × 50 × 60 mm | ZERNE: "603030 … 6.0mm in thickness, 30mm in width and 30mm in length" ([zerne-battery.com](https://www.zerne-battery.com/products/3-7-v-450mah-lithium-polymer-battery-603030.html)); BENZO's 803035 is 8 × 30 × 37 mm with PCM ([suppliers_asia.md](suppliers_asia.md) Q1) |
| Connector, chemistry, protection "not specified" | incomplete: the announcement names an MCH2022-compatible connector. The MCH2022 docs give it (JST ZH 1.5 mm, keyed). The flow3r schematic gives the charger (BQ24074, 500 mA) and its protection limits | section 1 |
| "500–1,000 mAh is a reasonable starting point" for a 30 × 34 mm badge | **wrong for this badge**: 600 mAh gives 3.6 h and 350 mAh 2.1 h, with the brightness cap | `herz_badge/sim/results/runtime.md` |
| 250 mA on 1000 mAh is about 4 h; 125 mA about 8 h | confirmed (arithmetic); the sim gives 4.1 h at 233 mA | `herz_badge/sim/results/runtime.md` |
| EMC: conducted emissions under the limit on a wall charger; radiated emissions much higher with a USB cable; bootloop at 30–40 MHz with only paper insulation | confirmed. But the write-up leaves out that radiated emissions also exceeded CISPR 32 on battery power (80 MHz, 400 MHz, about 1 GHz) | [dm2lct.radio](https://dm2lct.radio/blog/flow3r_badge/) |
| No battery incident reported for flow3r | confirmed in what I read. The flow3r schematic itself warns of missing undervoltage protection and thermal sensing | [bot-schematic.pdf](https://git.flow3r.garden/flow3r/flow3r-hardware/-/blob/main/boards/bot/bot-schematic.pdf) |

## 3. Write-up 2 (chemistry and form factor) checked

### Takeaway
The Battery University chemistry numbers are mostly right. The cycle-life range comes from BU-216, not BU-205 as cited. The conclusions are wrong for this badge, because the write-up assumes 5 V WS2812s behind a boost converter:
- It inflates the battery current by about 50 %.
- It inflates the capacity target to 1.5–3 Ah.
- It rules out the 103030 that the simulation shows works with the cap.

It gets the LED current wrong (60 mA instead of 36 mA per pixel) and the primary-lithium voltage wrong. It understates the form-factor problem: AAA cells do not merely "fit with difficulty" — at 44.5 mm they are longer than the board. It rejects LiFePO4 for a reason that does not apply, the ESP32 limit behind an LDO. The real reason is that the V6 LEDs need 3.3 V and LFP sits at 3.2–3.3 V.

### Cited findings
| Claim | Verdict | Primary source |
| --- | --- | --- |
| A 103030 "usually fails the runtime target"; LiPo needs a 5 V boost plus a level shifter | **wrong** (known): 6.0 h typical with the cap on 1000 mAh; the V6 is rated 3.3–5.3 V; a level shifter is already fitted (SN74LVC1T45) | `herz_badge/sim/results/runtime.md`; `herz_badge/docs/datasheets/C52917434_WS2812B-2020-V6.md` (p3); DESIGN D4 |
| "A full-white WS2812 pixel is commonly treated as approximately 60 mA" | **wrong for this part**: 12 mA per channel, 36 mA white | V6 datasheet summary (p1, p4) |
| 1.2 A on the 5 V rail needs "about 2.0 A" from the battery | **not applicable**: no boost; the white flash is 1.18 A straight from the cell, and D17 caps it at 800 mA | DESIGN sections 3 and 7 (D17) |
| Capacity target "1.5 Ah minimum, 2.0–3.0 Ah recommended" | **wrong for this badge**: built from 220–320 mA plus boost losses. The sim's battery current is 160 mA capped and 233 mA typical | `herz_badge/sim/results/runtime.md` |
| A 1–2 Ah pouch "cannot realistically fit entirely within a 30 × 34 mm badge" | **wrong at 0.8–1 Ah**: a 103030 is 10.5 × 30.5 × 32–33 mm with PCM; true at 2 Ah | DESIGN D11; [suppliers_asia.md](suppliers_asia.md) Q1 |
| LCO has "poor thermal stability and limited power capability" | confirmed: "low thermal stability and limited load capabilities"; thermal runaway 150 °C | [BU-205](http://www.batteryuniversity.com/article/bu-205-types-of-lithium-ion/) |
| LFP 90–120 Wh/kg, 1,000–2,000 cycles, runaway well above LCO | numbers confirmed by [BU-216](http://www.batteryuniversity.com/article/bu-216-summary-table-of-lithium-based-batteries/) (90–120 Wh/kg, 1000–2000 cycles, 270 °C against 150 °C). The cited BU-205 says "2000 and higher" cycles | [BU-205](http://www.batteryuniversity.com/article/bu-205-types-of-lithium-ion/) |
| LFP 3.2–3.3 V nominal, 3.65 V full, about 2.5 V cut-off | confirmed: 3.65 V full, 2.50 V full discharge, 2.00 V minimum | [BU-216](http://www.batteryuniversity.com/article/bu-216-summary-table-of-lithium-based-batteries/) |
| LFP needs a 3.65 V charger; a 4.2 V Li-ion charger overcharges it | confirmed. The TP4056 floats at 4.17–4.26 V | [BU-205](http://www.batteryuniversity.com/article/bu-205-types-of-lithium-ion/); `herz_badge/docs/datasheets/C725790_TP4056.md` (p5) |
| Running an ESP32-S3 directly from LFP is unsafe at 3.6–3.65 V and too low near empty | partly: the ESP32-S3 is rated 3.0–3.6 V, abs max 3.6 V, so a fresh LFP is 50 mV over. But behind the ME6217 the ESP32 is not the problem. The V6's 3.3 V minimum is: LFP's 3.2–3.3 V plateau is at or below it for nearly all of the discharge, so LFP needs a boost here | ESP32-S3 summary (p60); V6 summary (p3); BU-216 |
| A 3.3 V LDO "cannot regulate" below 3.3–3.4 V; buck-boost "more reliable" | true but small: the ME6217 drops 100 mV typical, 180 mV max at 300 mA. The firmware stops at VSW 3.4 V with 4–6 % of the charge left, and 3V3 is still 3.30 V there | `herz_badge/docs/datasheets/C427602_ME6217C33M5G.md`; `herz_badge/sim/results/runtime.md` |
| A raw 4.2 V Li-ion cell must not feed the ESP32-S3 | confirmed (abs max 3.6 V); the badge uses the LDO | ESP32-S3 summary (p60) |
| 14500 about 14 × 50 mm, does not fit; 18650 about 18 × 65 mm | confirmed by size names; neither fits a 34 mm board | [list of battery sizes](https://en.wikipedia.org/wiki/List_of_battery_sizes) |
| NiMH AAA 0.7–1.0 Ah, AA 1.9–2.5 Ah | confirmed: eneloop AAA "up to 800 mAh / min. 750", 10.5 × 44.5 mm; AA "up to 2000 mAh", 14.5 × 50.5 mm; eneloop pro AA min. 2450–2500 mAh | [Panasonic eneloop](https://www.panasonic.com/global/energy/products/eneloop/en/lineup/eneloop.html), [eneloop pro](https://www.panasonic.com/global/energy/products/eneloop/en/lineup/eneloop-pro.html) |
| Three AAA cells are "difficult to fit in the badge" | **understated**: an AAA is 44.5 mm long, 10.5 mm more than the board | [Panasonic eneloop](https://www.panasonic.com/global/energy/products/eneloop/en/lineup/eneloop.html) |
| NiMH has "significant self-discharge" | confirmed: nickel cells lose 10–15 % in the first 24 h, then 10–15 % a month; Li-ion loses 5 %, then 1–2 % a month plus 3 % for the protection circuit | [BU-802b](https://batteryuniversity.com/article/bu-802b-what-does-elevated-self-discharge-do) |
| Primary lithium AA/AAA "single cells can exceed 3.3 V when fresh" | **wrong**: lithium AA (Li-FeS2) is a 1.5 V system | [Energizer L91](https://data.energizer.com/pdfs/l91.pdf), [L91/L92 handbook](https://data.energizer.com/pdfs/lithiuml91l92_appman.pdf) |
| Sodium-ion "commonly approximately 3.0 V"; small cells hard to source | confirmed: a commercial 18650 Na-ion is 1.3 Ah, 3.1 V nominal, 1.5–3.95 V. I found cylindrical cells only, no small pouches (my search) | [ScienceDirect 2026](https://www.sciencedirect.com/science/article/pii/S2352152X26020797), [PHD Energy](https://phdenergy.com/sodium-ion-batteries/cylindrical-cells/) |
| 470–1,000 µF bulk capacitance at the LEDs | **unverified** (no source). The repo sim shows 2 × 10 µF plus 100 nF per row holds 3V3 ≥ 2.88 V in a white flash down to 5 % charge on 1000 mAh | `herz_badge/sim/results/flash_sag.md` |
| Alkaline capacity is rated at low current and sags at high load | unverified for numbers; not decision-relevant, since no alkaline pack fits (section 6) | — |

## 4. Write-up 3 (pouch-cell integration and safety) checked

### Takeaway
The protection numbers are right. DW01-class thresholds and Battery University's 4.30 V and 2.50 V check out against the Fortune DW01-G datasheet and BU. The handling advice matches NFPA and BU. The write-up says "confirm" where a number exists:
- IATA: Li-ion cells shipped alone must be at 30 % or less. Since 1 January 2026 the same applies to cells over 2.7 Wh packed with equipment. This badge's cell is 3.1–3.7 Wh, so air shipments of spare cells need 30 %. DESIGN.md's "40–60 %" is a storage figure and should be split.
- Battery University gives 8–10 % pouch growth over 500 cycles for small packs, about 1 mm for a 10 mm cell.

Its NTC advice assumes a pack NTC. These 2-wire cells have none, so the board NTC of hazard 3 is the right substitute. The DW01's over-current trip is set by the FETs. At 150 mV across two FETs it lands at about 2.5–4.5 A on the candidate cells, which suits D18's "2 A or more".

The EU removability rule is not in any write-up. From 18 Feb 2027 a portable battery must come out with commercially available tools, without "thermal energy, or solvents", and the removal instructions must stay online. The regulations note covers scope and exemptions ([regulations.md](regulations.md)).

### Cited findings
| Claim | Verdict | Primary source |
| --- | --- | --- |
| DW01-type thresholds: overcharge about 4.25–4.30 V, release 4.05–4.15 V, over-discharge 2.4–2.5 V, release 2.8–3.1 V | confirmed: DW01-G overcharge 4.25 ± 0.05 V, release 4.05 ± 0.05 V, over-discharge 2.40 ± 0.10 V, release 3.0 ± 0.10 V; over-current 150 ± 30 mV (10–20 ms); short circuit 1.35 V (5–50 µs). Its example: 25 mΩ per FET gives a 3 A trip | [Fortune DW01-G, rev 1.0, Jun 2009](https://www.mikrocontroller.net/attachment/200783/DW01-G-DS-10_EN.pdf) (p6–8) |
| The candidate cells' PCMs | Ufine 103035/803035: 4.28 V ± 50 mV, 2.4 V ± 100 mV, over-current 2.5–4.5 A, no NTC | [suppliers_asia.md](suppliers_asia.md) Q1 |
| Battery University: about 4.30 V overcharge and 2.50 V over-discharge | confirmed. BU-304b gives 2.20 V for over-discharge instead | [BU safety concerns](http://www.batteryuniversity.com/article/lithium-ion-safety-concerns/), [BU-304b](http://www.batteryuniversity.com/article/bu-304b-making-lithium-ion-safe/) |
| A fuse or PTC is supplemental; a PTC may be slow | consistent. BU describes the PTC and CID as built into the 18650 cap, which a pouch cell lacks. The WHY2025 test shows a slow protection letting a FET glow | [BU-304](http://www.batteryuniversity.com/article/bu-304-why-are-protection-circuits-needed/); [WHY2025 advisory](https://wiki.why2025.org/Badge/Fire_hazard); DESIGN F101 proposal |
| Use the pack's NTC to inhibit charging out of range | not applicable as written: the candidate cells list "NTC: No". BU's window is 0–45 °C, with fast charge only at 5–45 °C and no charging below freezing | [BU-410](http://www.batteryuniversity.com/article/bu-410-charging-at-high-and-low-temperatures/); [suppliers_asia.md](suppliers_asia.md) |
| Swelling allowance: "do not add an arbitrary amount", ask the supplier | **incomplete**: BU says small pouch packs "can grow 8–10 percent over 500 cycles" and mentions "up to 3 percent swelling incidents on a poor batch run" | [BU-301a](https://batteryuniversity.com/article/bu-301a-types-of-battery-cells) |
| Pouch packaging efficiency 90–95 % | confirmed | [BU pouch cell](http://www.batteryuniversity.com/article/pouch-cell-small-but-not-trouble-free/) |
| Don't puncture a swollen cell near heat or flame; the gases can ignite | confirmed | [BU pouch cell](http://www.batteryuniversity.com/article/pouch-cell-small-but-not-trouble-free/) |
| Warning signs: odour, heat, popping, swelling, colour change; don't charge a damaged or submerged cell | confirmed | [NFPA](https://www.nfpa.org/education-and-research/energy-transition/lithium-ion-batteries) |
| Water can be used on Li-ion fires (NFPA) | confirmed: "Firefighters should use water", because the cells hold a lithium salt, not lithium metal. The write-up's NFPA link path is wrong | [NFPA](https://www.nfpa.org/education-and-research/energy-transition/lithium-ion-batteries) |
| Store at moderate charge, cool | confirmed: capacity left after 1 year is 96 % at 40 % charge against 80 % at 100 % (25 °C), and 85 % against 65 % at 40 °C | [BU-808](http://www.batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries/) |
| Shipping: "confirm state-of-charge requirements" | **incomplete**. IATA 2026: Li-ion shipped alone (UN3480, PI 965) at ≤ 30 % SoC, cargo aircraft only unless approved. From 1 Jan 2026, cells packed with equipment (PI 966) at ≤ 30 %, in Section II for cells over 2.7 Wh. Cells contained in equipment (PI 967): ≤ 30 % "strongly recommended" | [IATA Battery Guidance, 2026](https://www.iata.org/contentassets/05e6d8742b0047259bf3a700bc9d42b9/lithium-battery-guidance-document.pdf) (p3, p13–14) |
| Charging while the load runs confuses termination | confirmed in general; the badge avoids it, because with USB in, the load runs from VBUS through D101 and the TP4056 sees only the cell | DESIGN section 4 |
| Protection circuits cannot stop an internal defect | confirmed | [BU-304b](http://www.batteryuniversity.com/article/bu-304b-making-lithium-ion-safe/) |
| (missing) EU removability | Art. 11(1): "readily removable and replaceable by the end-user" with "commercially available tools", no "thermal energy, or solvents"; instructions "permanently online". Applies from 18 Feb 2027 (Art. 96) | [Reg. (EU) 2023/1542](https://eur-lex.europa.eu/eli/reg/2023/1542/oj); scope in [regulations.md](regulations.md) |

## 5. Topic synthesis checked

### Takeaway
The synthesis is right on the regulatory facts it names:
- CE marking of batteries;
- INOBAT's 11,000+ collection points and 95 % recyclability;
- IATA SoC limits;
- Peetz0r's pouch-cell retrofit for WHY2025;
- DEF CON 26's 4 × AA.

Its sizing claims are wrong:
- A 30 × 34 mm board does not force 400–600 mAh. A 103030 holds 800–900 mAh.
- 1.2 A on such a cell is 1.2–1.4C, not "≥2C". With D17's 800 mA cap it is 0.8–0.94C.
- Its own runtime arithmetic does not add up.

It repeats a Reddit claim that LiFePO4 can feed the rail without an LDO, which is false for the V6 LEDs. "Hundreds of amps" from an unprotected 18650 is not in its cited page. It overstates what Hackaday reported about the WHY2025 epoxy. Its recommendation (a protected 800–1000 mAh LiPo, TP4056 with NTC, a padded compartment) agrees with the repo, except that ≥2C is not needed with the D17 cap.

### Cited findings
| Claim | Verdict | Primary source |
| --- | --- | --- |
| "30 × 34 mm footprint forces … a smaller pouch (~400–600 mAh, marginal)" | **wrong**: 103030 cells of 800–900 mAh fit the 34 mm length. 400–600 mAh is the 6 mm class (ZERNE 603030: 450 mAh) | [suppliers_asia.md](suppliers_asia.md) Q1; [ZERNE 603030](https://www.zerne-battery.com/products/3-7-v-450mah-lithium-polymer-battery-603030.html) |
| "The 1.2 A peak demands a cell rated ≥2 C" | **wrong**: 1.2 A is 1.2C on 1000 mAh and 1.4C on 850 mAh, and it comes only as 150 ms pulses. D17 caps the LEDs at 800 mA. The candidate cells are 1C continuous with 2.5–4.5 A PCM trips | DESIGN D17, D18; [suppliers_asia.md](suppliers_asia.md) |
| "5–8 h at 130–230 mA … 2.4–5.4 Wh (650–1450 mAh)" | **wrong arithmetic**: 230 mA × 8 h is 1840 mAh (6.8 Wh). The figures also leave out the radio's 93 mA; the sim's battery current is 128–364 mA | `herz_badge/sim/results/runtime.md` |
| LiFePO4 "can even run it without an LDO" / "can feed the rail directly" | **wrong for this badge**: fresh LFP (3.65 V) exceeds the ESP32-S3's 3.6 V maximum, and the plateau (3.2–3.3 V) is under the V6's 3.3 V minimum. The source is a Reddit thread | [BU-216](http://www.batteryuniversity.com/article/bu-216-summary-table-of-lithium-based-batteries/); ESP32-S3 and V6 summaries |
| LiPo pouch "~300 Wh/L" | confirmed roughly: 850 mAh × 3.7 V in 10.5 × 30.5 × 32.5 mm with PCM is about 300 Wh/L; 1000 mAh in the bare 9 cm³ is about 410 Wh/L (my arithmetic) | [suppliers_asia.md](suppliers_asia.md) |
| LiFePO4 trades "~30–40 %" energy density | confirmed by weight: 90–120 against 150–200 Wh/kg (LCO) | [BU-216](http://www.batteryuniversity.com/article/bu-216-summary-table-of-lithium-based-batteries/) |
| NiMH "needs 2–3 cells + boost" | partly: 3 cells (3.0–4.5 V) would run the V6 without a boost, but no 3-cell pack that fits gives more than 2.5 h (section 6) | BU-215; section 6 |
| "Peetz0r's guide recommends replacing the 18650 holders with LiPo pouch cells" | confirmed: "Remove the unused 18650 holders" and "Replace them with 1 or 2 protected pouch cells", under "Recommended hardware mods" | [peetz0r.nl/badge](https://peetz0r.nl/badge) |
| "Hackaday's coverage documents … epoxy coating of traces" | **partly wrong**: Hackaday says "epoxy coating to the boards". The advisory says the epoxy went over the exposed solder joints, and calls that insufficient because it leaves the traces and holder tabs as they were | [Hackaday](https://hackaday.com/2025/08/12/when-a-badge-misses-the-mark-why-2025/); [advisory](https://wiki.why2025.org/Badge/Fire_hazard) |
| "Unprotected 18650s can deliver hundreds of amps into a short" (cites BU) | **unverified**: the cited BU page gives no short-circuit current. The advisory says only that the cells can supply more than the 20 A it tested | [BU safety concerns](http://www.batteryuniversity.com/article/lithium-ion-safety-concerns/); [advisory](https://wiki.why2025.org/Badge/Fire_hazard) |
| Cells must be "CE-marked, correctly labelled", with take-back | confirmed for batteries made available on the EU market: Art. 20 (CE marking before placing on the market); Art. 13 (collection symbol from 18 Aug 2025, capacity label from 18 Aug 2026 or later). Whether a free badge counts is in [regulations.md](regulations.md) | [Reg. (EU) 2023/1542](https://eur-lex.europa.eu/eli/reg/2023/1542/oj) |
| INOBAT "11,000+ collection points, up to 95 % recyclability" | confirmed: "Über 11'000 Sammelstellen", "Bis zu 95 %" | [inobat.ch](https://www.inobat.ch/) |
| IATA requires SoC limits for standalone Li-ion | confirmed (≤ 30 %); see section 4 for the 2026 change | [IATA 2026](https://www.iata.org/contentassets/05e6d8742b0047259bf3a700bc9d42b9/lithium-battery-guidance-document.pdf) |
| DEF CON 26: 4 × AA | confirmed | [Hackaday, 9 Aug 2018](https://hackaday.com/2018/08/09/first-look-at-def-con-26-official-badge/) |
| r0ket, card10, flow3r used LiPo pouches | r0ket confirmed ("LiPo"). card10's page gives only "200 mAh". flow3r gives a pouch size code, not a chemistry | section 1 |
| flow3r's LED load "closely matches the 130–230 mA" scenario | **unverified**: flow3r gives only a 1.1 A worst case (speakers, LEDs, display) | [bot-schematic.pdf](https://git.flow3r.garden/flow3r/flow3r-hardware/-/blob/main/boards/bot/bot-schematic.pdf) |
| EMF replacement parts "imply serviceable battery mounting" | **partly wrong**: the spare cell is sold, but it is held by "very strong glue dots" that need adhesive remover or isopropyl | section 1 (Tildagon) |
| "Add ≥470 µF bulk capacitance near the LED rail" | **unverified** (no source); see section 3 | `herz_badge/sim/results/flash_sag.md` |
| "Verify the PCM's overcurrent trip exceeds ~1.5 A" | consistent with D18 (≥ 2 A) and the candidates' 2.5–4.5 A | DESIGN D18 |

## 6. Chemistry verdict for this badge

### Takeaway
Only a Li-ion pouch (LCO/NMC LiPo) fits behind 30 × 34 mm at ≤ about 11 mm and meets 5 h. It needs the brightness cap of D17 to do so.

A 103030 holds 3.1 Wh at the honest 850 mAh, or 3.7 Wh at the labelled 1000 mAh. On a typical crowd with the cap that gives 5.1 h, or 6.0 h at 1000 mAh. Without the cap it gives 3.5 h, or 4.1 h at 1000 mAh. On an 850 mAh cell, 6 h needs an average of 136 mA or less and 8 h needs 102 mA or less. The radio alone draws 93 mA. So the 8 h end of the target needs the beat-locked listen windows of DESIGN section 3, not a bigger cell, because no bigger cell fits.

Every other chemistry fails here, whether on size, on voltage, or on both:
- **LiFePO4** sits at or below the LEDs' 3.3 V minimum, the TP4056 would overcharge it, and it stores about 40 % less energy (BU-216, by weight).
- **NiMH:** the only pack that fits, 3 × 2/3AAA, holds 1.4 Wh, which is ≤ 2.5 h.
- **Alkaline** needs three cells to stay above 3.3 V, and none fit.
- **Primary lithium** is either 1.5 V AA/AAA (too long) or 3.0 V (below the LEDs and too thick).
- **Sodium-ion** comes only in 18650 and larger, and most of its 1.5–3.95 V range is below 3.3 V.

The LP962830 (9.6 × 28 × 30 mm, 850 mAh) has the same capacity and avoids the 103030's 0.5 mm overhang.

### Cited findings
Loads from `herz_badge/sim/model.py` and `herz_badge/sim/results/runtime.md`:
- ESP32-S3 with the radio receiving: 93 mA.
- Heart: 35, 139 or 271 mA for quiet, typical or packed, and 67 mA typical with the cap at 60.
- Battery current: 128, 233 or 364 mA, and 160 mA typical with the cap.
- The cell is cut off at VSW 3.4 V with 4–6 % of its charge left.

Runtimes for other cells are capacity × 0.95 ÷ current (my arithmetic, upper bounds).

| Option, at ≤ 30 × 34 × 11 mm | Fits? | Energy | Typical with cap (160 mA) | Typical uncapped (233 mA) | Meets 5–8 h? | Sources |
| --- | --- | --- | --- | --- | --- | --- |
| LiPo 103030, as labelled 1000 mAh | yes: 10.5 × 30.5 × 32–33 mm with PCM, 0.5 mm over the 30 mm width | 3.7 Wh | 6.0 h (quiet 7.5 h, packed 2.6 h) | 4.1 h | yes, with the cap | sim; [suppliers_asia.md](suppliers_asia.md) |
| LiPo 103030, honest 850 mAh (or LP962830, 28 mm wide) | yes | 3.1 Wh | 5.1 h (quiet 6.4 h, packed 2.2 h) | 3.5 h | only just, with the cap; 8 h needs ≤ 102 mA | sim × 0.85; [suppliers_asia.md](suppliers_asia.md) |
| LiFePO4 pouch in the same 9 cm³ | no small LFP pouch found (my search). Est.: about 40 % less energy (90–120 against 150–200 Wh/kg) | est. 1.9–2.2 Wh, 0.6–0.7 Ah | ≤ 4.4 h, if the LEDs ran at all | ≤ 3 h | **no**: 3.2–3.3 V plateau ≤ the V6's 3.3 V minimum; the TP4056 floats at 4.2 V against LFP's 3.65 V | [BU-216](http://www.batteryuniversity.com/article/bu-216-summary-table-of-lithium-based-batteries/); V6 and TP4056 summaries |
| Li-ion cylinders (14500, 10440, 16340) | **no**: a 14500 is 50 mm long and a 10440 44 mm; a 16340 is 16 mm thick | — | — | — | no | [list of battery sizes](https://en.wikipedia.org/wiki/List_of_battery_sizes) |
| NiMH 3 × 2/3AAA (10.5 × 29 mm, 400 mAh each), side by side | yes: 31.5 × 29 × 10.5 mm | 1.4 Wh (3.6 V × 0.4 Ah) | ≤ 2.5 h | ≤ 1.7 h | **no**; also needs a NiMH charger, and loses 10–15 % a month | [battery size chart](https://www.batterycanada.com/battery-sizes.asp); [BU-802b](https://batteryuniversity.com/article/bu-802b-what-does-elevated-self-discharge-do) |
| NiMH or alkaline AAA, 3 cells | **no**: 44.5 mm long | — | — | — | no | [Panasonic eneloop](https://www.panasonic.com/global/energy/products/eneloop/en/lineup/eneloop.html) |
| Alkaline N (12.0 × 30.2 mm), 3 cells | **no**: 36 mm wide side by side, 12 mm thick | — | — | — | no; 2 cells (3.0 V) are under the V6's minimum | [N battery](https://en.wikipedia.org/wiki/N_battery); [Energizer E90](https://www.farnell.com/datasheets/1750386.pdf) |
| Primary lithium: Li-FeS2 AA/AAA, or 3 V CR2 (15.6 × 27 mm) | **no**: AA/AAA too long; CR2 is 15.6 mm thick and 3.0 V | — | — | — | no | [Energizer L91](https://data.energizer.com/pdfs/l91.pdf); [PKCELL CR2](https://www.pkcell.com/essential-cr2-lithium-3-volt-battery-guide/) |
| Sodium-ion | **no**: smallest found is an 18650 | — | — | — | no; 3.1 V nominal, 1.5–3.95 V | [ScienceDirect 2026](https://www.sciencedirect.com/science/article/pii/S2352152X26020797) |

- The 850 mAh row: every runtime in DESIGN.md section 3 shrinks by 10–15 % with a real cell ([suppliers_asia.md](suppliers_asia.md)). The 5 h end of the target holds only with the cap. The typical crowd without the cap (3.5 h) and the packed crowd (2.2 h) do not reach it.
- What would close the gap, in order of effect:
  1. Radio listen windows. The 93 mA receive floor is 58 % of the capped 160 mA.
  2. A lower battery cap, for example 40 instead of 60 (not simulated).
  3. A 9.6–10 mm cell that uses all 34 mm of length. None exists as a standard part: the 35 mm sizes are 37 mm with PCM ([suppliers_asia.md](suppliers_asia.md)).
- On an 850 mAh cell the average load is 0.19C (capped) to 0.43C (packed crowd), and 0.94C at the cap's 800 mA. That is inside the candidates' 1C continuous rating. It is also inside BU's LCO discharge figure of "1C; 2.50V cut off" ([BU-205](http://www.batteryuniversity.com/article/bu-205-types-of-lithium-ion/)).
