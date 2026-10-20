# Badge battery options

Status: 2026-10-18. Research only; no hardware or firmware was changed beyond the design notes. The question: which battery suits the battery badge (`herz_badge/`), and where a Swiss team can buy 10, 100 or 1000 cells from reputable makers that meet EU and Swiss rules for making, using at events and disposing of batteries. The notes behind each section are in [research_notes/Badge battery options/](../research_notes/Badge%20battery%20options/). The safety changes are in [herz_badge/DESIGN.md](../herz_badge/DESIGN.md), section 5 and decisions D18–D19.

## Short answer

- **Keep a protected single-cell LiPo pouch.** Nothing else holds enough energy behind a 30 × 34 mm board (section 2).
- **A real 103030 holds 800–900 mAh, not 1000.** With the brightness cap of D17, that gives **5.1–5.4 h** in a typical crowd, the low end of the 5–8 h target.
  - Cheapest lever: a board 3 mm longer would take a 103035 (about 1100 mAh, 6.6 h).
  - Bigger lever: the radio's 90 mA, through listen windows locked to the beat.
- **No Swiss or European source sells a fitting protected cell of 800 mAh or more.** Mouser and DigiKey don't sell LiPo cells to Switzerland at all.
- **Prototypes:** buy them from Swiss stock (Jauch LP102530JU, 680 mAh, CHF 15.45, a real datasheet with UN 38.3), plus 10 samples each from two or three Chinese factories.
- **Production:** order from the factory whose samples pass. Landed, a cell then costs about **CHF 2.0–2.4 at 100 and CHF 1.4–1.8 at 1000**.
- **Choose suppliers on documents, not price.** Ask for:
  - a UN 38.3 test summary;
  - an IEC 62133-2 CB report that can be checked on the IECEE site;
  - a datasheet;
  - the protection-board specification.

  Two of the three Alibaba sellers first shortlisted show red flags.
- **Safety changes, now in DESIGN.md:**
  - protected cells only, checked on arrival;
  - an insulating sheet and spacer behind the board;
  - a charge-temperature NTC (IEC 62368-1 asks for one);
  - a fuse to decide;
  - move the battery connector out from under the cell.
- **Rules:**
  - **Switzerland:** the INOBAT disposal fee on directly imported cells is CHF 0.05 each. You have to register, and file reports every quarter.
  - **EU, if badges are "on the market" (unsettled for a hobby giveaway):**
    - an EU-based company has to be named as the one placing them on the market;
    - German registrations with stiftung ear, for the battery and for the badge;
    - CE on the cell and on the badge;
    - from 18 Feb 2027, a cell the user can change: hook-and-loop or a strap, not foam tape.
  - **Transport:** finished badges travel by car or van in marked boxes, not by train or as plane luggage. Loose cells never go by post.

## 1. What the cell has to do

From `herz_badge/DESIGN.md` sections 3–5:

**Electrical:**
- 3.7 V single cell, charged to 4.2 V by a TP4056 at 400 mA.
- Load 130–230 mA in a typical crowd: about 90 mA radio plus the heart.
- White flashes add 1.18 A for 150 ms at a time. Firmware will cap the total at about 0.8 A.
- So the cell needs at least 1C continuous discharge, and a protection board (PCM) that trips above about 2 A.

**Mechanical:**
- Flat behind the 30 × 34 mm board, at most about 10–11 mm thick.
- JST PH 2.0 plug with pin 2 = +.

**What real cells hold:** makers that publish full datasheets rate a 103030 at 800–900 mAh. With the PCM folded on top it measures about 10.5 × 30.5 × 32–33 mm: 0.5 mm wider than the board, inside its length. The "1000 mAh" Alibaba listings weigh 13–15 g, which would mean 250–285 Wh/kg, at or above the best cells Grepow makes ([suppliers_asia.md](../research_notes/Badge%20battery%20options/suppliers_asia.md) Q1).

The repo's simulation (`herz_badge/sim/runtime.py`, run with the real capacities; cell resistances assumed):

| Cell | Fits 30 × 34? | Typical crowd, capped at 60 | Quiet / typical / packed, uncapped |
| --- | --- | --- | --- |
| Jauch LP102530JU, 680 mAh | yes | about 4.1 h (scaled) | about 5.1 / 2.8 / 1.8 h (scaled) |
| 103030, 850 mAh | yes, 0.5 mm wide | 5.1 h | 6.4 / 3.5 / 2.2 h |
| 103030, 900 mAh | yes, 0.5 mm wide | 5.4 h | 6.8 / 3.7 / 2.3 h |
| 103035, about 1100 mAh | needs a 37 mm board | 6.6 h | 8.3 / 4.5 / 2.9 h |

Without the cap, no cell that fits reaches 5 h in a crowd.

## 2. Which kind of battery

Only a lithium-ion pouch (LiPo) fits behind 30 × 34 mm at no more than about 11 mm and reaches 5 h. Everything else
fails on size, on voltage, or on both. The LEDs need at least 3.3 V
([homelib_research.md](../research_notes/Badge%20battery%20options/homelib_research.md) section 6).

| Option | Fits? | Energy | Verdict |
| --- | --- | --- | --- |
| LiPo pouch 103030, 850–900 mAh | yes, 0.5 mm wide | 3.1–3.3 Wh | 5.1–5.4 h with the cap: the choice |
| LiPo pouch LP962830, 850 mAh, 9.6 × 28 × 30 mm | yes, inside the outline | 3.1 Wh | same runtime, no overhang; one maker, data to verify |
| Li-ion 14500 or 18650 | no: 50 or 65 mm long | — | only on a bigger badge |
| LiFePO4 | size yes | about 40 % less | sits at 3.2–3.3 V, at or below the LEDs' minimum; the TP4056 would overcharge it |
| NiMH, 3 × 2/3AAA | yes | 1.4 Wh | under 2.5 h |
| Alkaline AAA or N, three cells | no | — | — |
| Primary lithium | no | — | 1.5 V AA/AAA cells are too long; 3 V cells are too low and too thick |
| Sodium-ion | no | — | 18650 and larger only, and mostly below 3.3 V |

The 8 h end of the target can't come from the cell. On 850 mAh, 8 h needs an average of 102 mA or less, and the radio
alone draws 93 mA. It needs the beat-locked listen windows from the mesh research.

**What 21 earlier badges did** (same note, section 1; from their own docs, schematics and BOMs):
- **Most used one lithium cell (15 of 21).** The rest used AA cells (Supercon 2023/24, DEF CON 26, BornHack 2025) or
  WHY2025's two 18650s.
- **Protection.**
  - Protected cells: SHA2017, MCH2022 and Fri3d 2024. Fri3d 2022 put a DW01-P and FS8205A on the board instead.
  - flow3r's schematic warns: "No undervoltage protection! No auto shutdown!"
  - Only WHY2025 handed out unprotected cells, and it was the only badge with a public incident.
- **Mounting.**
  - Glue dots: card10, flow3r and Tildagon. EMF's guide needs adhesive remover or 99 % isopropyl to get the Tildagon's
    cell off, and EU Art. 11 rules out removal with solvents.
  - Velcro and a keyed plug: MCH2022, the best precedent for a cell a user can change.
  - EMF raised the Tildagon 2026's board spacing by 1 mm "to avoid battery squishing", the hazard the D19 spacer
    covers.
- **Charging.**
  - JST PH 2.0 is the common plug.
  - Charge currents ran at 0.25–1C (SHA2017: 1 A into 1000 mAh, with a TP4056).
  - r0ket, rad1o and SHA2017 used a 3-pin JST with an NTC line, and Fri3d 2024 put an NTC on its TP4056's TEMP pin:
    precedents for the NTC proposed here.
- **Reuse.** Cells were reused between events: flow3r takes MCH2022's cell, and the Tildagon takes the 2016 and 2018 EMF
  cells. A badge whose cell plugs in and comes off cleanly keeps its value.

## 3. Making the LiPo safe

WHY2025 is the warning. Its badge was declared a fire hazard during the event ([advisory](https://wiki.why2025.org/Badge/Fire_hazard)):
- unprotected 18650 cells;
- traces 0.4 mm from ground under thin solder mask;
- a protection circuit too slow in a 20 A test.

Attendees were told to remove the cells and run the badge from USB.

The battery badge had its own gaps, now listed as nine hazards in [DESIGN.md section 5](../herz_badge/DESIGN.md):
- **No fuse:** only the cell's PCM opens a short.
- **No charge-temperature check:** TEMP is tied to GND.
- **Heat:** the charger sits under the cell.
- **Pressure points:** the 5.5 mm battery connector and part of the USB-C shell are inside the cell's outline, so a pouch laid flat rests on connector edges.
- **Not an off state:** deep sleep still draws about 0.2 mA, and drains a forgotten badge to its cut-off within a week or two.

What changed:
- **D18, buying.** Only cells with a PCM, a datasheet allowing 0.5C charge and 1C discharge, a UN 38.3 summary and an IEC 62133-2 report for that model, the crossed-out bin printed on the cell, and the JST fitted pin 2 = +. Every cell is metered on arrival. Samples get a PCM trip test and a capacity test.
- **D19, mounting.**
  - A polyimide sheet over the back.
  - A foam spacer as thick as the tallest part, so the pouch lies flat.
  - A reusable fastener (hook-and-loop, as MCH2022 used, or a strap) instead of permanent tape, so the user can change the cell (EU Art. 11, section 4).
- **Proposed for routing:**
  - a 2 A fast fuse (Littelfuse 0466002.NRHF, 31 mΩ) between the connector and the reverse guard;
  - a 10 kΩ NTC under the cell with 5.6 kΩ / 120 kΩ on TEMP, which stops charging outside about 0.5–46 °C. IEC 62368-1 Annex M.4.2 requires this for a safety claim ([regulations.md](../research_notes/Badge%20battery%20options/regulations.md) section 6);
  - J102 and the charger moved out of the cell's outline.
- **To measure on the first badges:** the deep-sleep and off currents, the cell's surface temperature over the charger, and the PCM's trip points.

## 4. Rules

Detail and sources: [regulations.md](../research_notes/Badge%20battery%20options/regulations.md) for the EU, Germany, transport and events; [regulations_switzerland.md](../research_notes/Badge%20battery%20options/regulations_switzerland.md) for Switzerland. Not legal advice.

### Switzerland: buying and importing the cells
- **Labels and substances.** The ChemRRV (Annex 2.15) asks for a crossed-out bin and the capacity on each cell, and limits mercury and cadmium. It has **no removability rule**, and no draft adopts the EU Battery Regulation.
- **The disposal fee (VEG).** It is owed to INOBAT by whoever imports batteries "beruflich oder gewerblich": CHF 0.05 per Li-ion cell of 1–49 g, so about CHF 50 per 1000 cells.
  - Cells bought from a Swiss shop already include it.
  - A direct import means registering and filing a self-declaration every quarter, a nil report included.
  - Batteries exported again can be refunded.
  - Whether a hobby team counts as an importer is not settled: ask INOBAT (031 380 79 30).
- **Customs.** Cells come in duty-free (tariff 8507.6000). Import VAT is 8.1 %, and isn't collected when the tax is CHF 5 or less. Clearance fees are CHF 13–25.
- **Disposal.**
  - Intact cells go back to any battery shop or municipal point.
  - Damaged or swollen cells go only to staffed points, terminals taped. INOBAT runs a free 24/7 emergency service.
  - Batrec in Wimmis recycles them.

### EU and Germany: handing out or selling badges at a CCC event
- **Whether the rules apply depends on "making available on the market".** That is any supply "in the course of a commercial activity, whether in return for payment or free of charge".
  - The Commission's Blue Guide treats occasional supplies by hobbyists as not commercial in principle, but case by case.
  - A one-off giveaway is arguably outside. Selling 100–1000 badges, or selling through the organiser, leans commercial.
  - A *Feststellungsantrag* (binding ruling) at stiftung ear would settle it.
- **If they are on the market:**
  - **An EU-based operator.** A Swiss team alone can't be the EU producer or importer: Regulation 2019/1020 Art. 4 requires an EU-based operator named on the product or its packaging. The options are the CCC's company CCCV GmbH (which sold the flow3r badge through the ticket shop in 2023), a German club, or a German authorised representative.
  - **Two German registrations at stiftung ear,** each through a German representative, with no minimum quantity: the BattDG for the cell (with a producer responsibility organisation) and the ElektroG for the badge (with a WEEE guarantee). Fines reach EUR 100,000.
  - **CE marking and a declaration of conformity.** For the cell under the Battery Regulation, required since 18 Aug 2024. For the badge as radio equipment under RED: EN 62368-1, EN 300 328, EN 301 489, EN 62311.
  - **Labels.** The crossed-out bin on the cell (about 5.2 mm square on a 30 × 30 mm face) since 18 Aug 2025. A QR code from 18 Feb 2027.
- **Removability (Art. 11) from 18 Feb 2027.** It covers badges handed out at a summer 2027 camp, but not at the December 2026 Congress.
  - The JST plug is fine. Strong foam tape isn't: the Commission's July 2026 guidelines ask that the user can take the battery out without damaging it or the device, and that non-reusable fasteners are sold as spares.
  - Publish removal instructions online, and keep spare cells for 5 years.
  - The new wearables exemption doesn't fit an open board with a plug-in cell.

### Transport
- **Cells by air.** Loose cells (UN3480) are fully regulated: cargo aircraft only, at most 30 % charge, a shipper's declaration, DG-approved accounts. DHL China adds CNY 800 (about CHF 99) per shipment.
- **Cells by freight service.** Chinese "battery line" services (air plus ground, 20–35 days) cost a half to a quarter as much, but sometimes arrive without customs papers.
- **No post.** Swiss Post and international mail refuse loose cells.
- **Paperwork.** The UN 38.3 summary has to be made available by the seller; without it, cells can't legally travel at all.
- **Finished badges to Germany.** By car or van, under ADR special provision 188: badges off with the switch secured, each protected, strong boxes with a UN 3481 mark. Not by train with the batch, and not as plane luggage (15 devices per person, personal use).
- **Customs into Germany.** Hundreds of badges must be declared, with German import VAT at 19 %. Duty is 0 % if the boards' Swiss assembly gives them Swiss origin. An ATA carnet can't be used for goods given away or sold.

### At the event
The CCC publishes no lithium-specific rules. From German fire-safety guidance (DGUV, bvfa):
- **Charging:** supervised, on a non-combustible surface, out of the sun and out of escape routes. No cold cells on the charger.
- **Fire:** water, sprayed from at least 1 m, is the right extinguisher for small lithium cells; not CO2, powder or Class D. Keep a metal box of sand or vermiculite for a hot cell.
- **Damaged cells:** a supervised collection box, terminals taped. Hand them in locally in Germany (a GRS point or a municipal recycling yard). Damaged cells can't travel home under SP 188.
- **If badges are sold:** free take-back at the stall, with a German sign.

## 5. Where to buy

Detail: [suppliers_europe.md](../research_notes/Badge%20battery%20options/suppliers_europe.md) and [suppliers_asia.md](../research_notes/Badge%20battery%20options/suppliers_asia.md). Prices as listed 17–18 October 2026, 1 USD = 0.824 CHF.

Landed means the cell plus its share of freight, 8.1 % VAT and the CHF 0.05 INOBAT fee. All figures are estimates.

| Option | Cell | Fits? | Documents seen | Landed CHF per cell at 10 / 100 / 1000 |
| --- | --- | --- | --- | --- |
| Conrad CH via Galaxus/Digitec (Swiss stock) | Jauch LP102530JU, 680 mAh, 10 × 26 × 32 mm, PCM, 1C | yes | datasheet, "UN 38.3 YES", "IEC 62133 NO" | 15.45 / about 7.70 (Jauch quote) / about 6.31 (Jauch quote) |
| Conrad CH or TME | Akyga LP103035, 1050 mAh, JST SYP plug | no, 37.5 × 31 mm | datasheet, MSDS, no UN 38.3 summary | 13.95 / about 5.12 / about 4.71 |
| Shenzhen WLY (Wiliyoung), factory | 103030, 900 mAh, 18 g, PCM, 1C | 0.5 mm wide | SGS-verified seller profile; certificates on request | 6.07 / 2.10 / 1.39 by battery line; 21.53 / 3.96 / 1.73 by express |
| Guangdong Ufine / BENZO, factory | 903030, 800 mAh, 32 mm max; or 103030, 850 mAh | yes / 0.5 mm wide | published PCM trip points; certificates on request | 5.99–6.82 / 2.01–2.37 / 1.39–1.75 by battery line |
| Shenzhen Data Power (DTP), factory | 103030 by quote | 0.5 mm wide | BV-audited | about 6.82 / 2.37 / 1.57 by battery line |
| LiPol, factory | LP962830, 850 mAh, 9.6 × 28 × 30 mm | yes, the only one not over the width | its own tables contradict each other; sample test needed | no public price |
| Grepow, EEMB | none in this footprint | — | the most reputable | custom run at 1000+ |

Notes:
- **Not available.** LCSC and JLC sell no loose cells. Mouser and DigiKey won't ship LiPo cells to Switzerland. Farnell CH has none.
- **Maker shops.** BerryBase, Eckstein, bastelgarage, pi-shop, play-zone, EXP-Tech and Pimoroni have nothing in the footprint at 800 mAh or more.
- **Red flags on the first shortlist:**
  - Dongguan Mozhong (LUNKE): founded 2024; "semi-solid" in one listing, "liquid" in another; an impossible 1000 mAh at 13–15 g.
  - Huizhou Jiaxinrui: "solid-state" pouches "for EVs", and 18650s at US$ 0.72.

  The first BOM's CHF 0.68–0.85 came from Jiaxinrui listings for other sizes.
- **Documents.** None of the Chinese makers shows a UN 38.3 summary or an IEC 62133-2 report for the actual model on a public page, and none names a JST PH pin order. Both go into the order: "PCM, JST PH 2.0 housing PHR-2, pin 1 = black = −, pin 2 = red = +".
- **European makers.**
  - Jauch builds prototypes and small series in Germany, with its own UN 38.3 lab. It is the European route to a custom 103030 with JST PH and NTC, at about 3–4 times the factory price.
  - Renata's largest cell in this footprint is 560 mAh, charges to 4.35 V and is made in China.
  - VARTA's LPP packs are too big, and VARTA filed for insolvency in July 2026.

## 6. Plan

1. **Now:**
   - Order 2–4 Jauch LP102530JU from Galaxus for the first boards.
   - Ask WLY, Ufine/BENZO and DTP for: their 103030 (or 903030) with PCM and JST PH in our pin order, the UN 38.3 summary, the IEC 62133-2 CB certificate and report, the datasheet, the PCM specification and a drawing with the lead exit.
   - Add LiPol for the LP962830.
2. **Samples:** 10 per supplier by battery line, about CHF 60 each. On arrival:
   - dimensions, polarity and open-circuit voltage of every cell;
   - a capacity test at 0.2C and at the badge's load on three cells;
   - a PCM short-circuit and over-current trip test;
   - check the certificate number on the IECEE site;
   - look for swelling after a full charge.
3. **Decide the board** (DESIGN.md section 5):
   - the fuse after re-running `sim/flash_sag.py`;
   - the NTC;
   - J102 and the charger out of the cell's outline;
   - a 34 mm board (850–900 mAh) or a 37 mm one (1100 mAh).
4. **Decide who places the badges on the market**, before a summer 2027 camp: CCCV, a German club, or a representative. A *Feststellungsantrag* can settle whether a hobby giveaway needs it at all. Ask INOBAT whether a hobby import owes the fee.
5. **Production lot:** 100 or 1000 from the winning factory, with the documents in hand. Register with INOBAT before the import if the fee applies.
6. **Before the event:**
   - pack for the car under SP 188;
   - agree a charging point with the organisers;
   - bring a water extinguisher, a sand box and a damaged-cell box;
   - put the removal instructions online if the camp is after 18 Feb 2027.

## 7. How this was researched

- **homelib.** The library's new `badge-batteries` topic has 58 sources: badge precedents, Battery University, protection and charger notes, safety guidance and the regulations. homelib ran three research runs (badge precedents, chemistry and form factor, pouch-cell integration) and a topic synthesis. The write-ups were LLM-generated and partly wrong, so every claim used here was checked against a primary source in [homelib_research.md](../research_notes/Badge%20battery%20options/homelib_research.md). The synthesis is kept, marked unverified, in [homelib_topic_synthesis.md](../research_notes/Badge%20battery%20options/homelib_topic_synthesis.md).
- **Suppliers and rules.** Researched directly with web search and llmlayer, by separate agents for EU and German rules, Swiss rules, European suppliers and Asian factories. Keirolabs was not used: its key sits in another tool's configuration, and reading it was blocked.
- **Gaps:**
  - Alibaba company profiles, conrad.ch and TME showed bot checks and were skipped, or read from search snippets (marked in the notes).
  - No supplier publishes a freight price to Switzerland. The landed costs are estimates from published surcharges and supplier statements.
  - homelib cost about $0.55 in total: adding and processing the sources, three research runs and one synthesis.
