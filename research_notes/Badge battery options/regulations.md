# Battery rules for the Herz badge: EU, Germany, transport, events and cell documents (state: October 2026)
Source: primary legal texts on eur-lex.europa.eu, gesetze-im-internet.de, fedlex.admin.ch and otif.org, Commission guidance on environment.ec.europa.eu, stiftung-ear.de, the IATA 2026 lithium battery guidance and carrier pages, events.ccc.de, wiki.why2025.org, DGUV and fire-service leaflets, and IECEE. Gathered 2026-10-17/18.

Scope note:
- This covers questions 1, 2, 4 (transport only), 5 and 6. The Swiss rules are in [regulations_switzerland.md](regulations_switzerland.md): ChemRRV Annex 2.15, the INOBAT advance disposal fee, disposal routes in CH and DE, and customs and VAT.
- Project facts come from `herz_badge/DESIGN.md`: one 103030 LiPo of 1000 mAh (about 3.7 Wh, about 20 g) with a PCM, on a JST PH and taped behind the 30 × 34 mm board; TP4056 at 400 mA with TEMP to GND; no fuse.
- Event dates: 40C3 is 27–30 Dec 2026 at Hamburg Messe, no longer the CCH ([events.ccc.de, 2 Jul 2026](https://events.ccc.de/en/category/40c3/)). No 2027 Camp has been announced. The CCC says the Camp "usually takes place every four years in August" ([events.ccc.de/camp](https://events.ccc.de/en/camp/)), so I assume August 2027.
- Labels: **[P]** = read in the primary source; **[S: name]** = secondary source; **[U]** = could not verify. Interpretations are marked "my reading".
- This is not legal advice. Where the law is unclear, I say so and say what would settle it.

---

## 1. EU Battery Regulation (EU) 2023/1542, plus GPSR and RED

### Takeaway
**The Regulation applies to this cell.** The 103030 cell with its PCM is a **portable battery**: sealed, under 5 kg, and not an industrial, LMT, SLI or EV battery. It is not a "portable battery of general use" (AA, 9 V and similar), so the performance rules in Art. 9 do not apply.

**It only applies if the badges are "made available on the market".** That means supplied "in the course of a commercial activity, whether in return for payment or free of charge". The Blue Guide says "occasional supplies by charities or hobbyists" are in principle not commercial, but it treats this as a case-by-case test.
- A one-off giveaway by a hobby team at a non-profit camp is arguably outside.
- Selling 100–1000 identical units at two events leans towards commercial.
- So does selling through the organiser's company, as the flow3r badge was sold through the CCC ticket shop in 2023.

No law or guidance settles this. For Germany, a binding answer would come from a *Feststellungsantrag* at stiftung ear (section 2).

If the badges are on the market, these points decide what we must do:

1. **We need an EU-based operator.** In the Regulation, the "producer" (Art. 3(47)(a)–(c)) and the "importer" (Art. 3(64)) must be established in the EU. Regulation (EU) 2019/1020 Art. 4 requires an EU-established operator for every product covered by RED, RoHS or 2023/1542, and that operator's name and address must appear on the product or its packaging. A Swiss team on its own does not qualify. The options are the organiser's company (CCCV GmbH, Berlin), a German club, or an authorised representative.
2. **Removability (Art. 11) applies from 18 Feb 2027.**
   - It does not cover badges handed out at 40C3 in December 2026. It does cover badges handed out at a 2027 Camp.
   - The JST plug is fine: no solder, no special tools.
   - The weak point is adhesive tape. The Commission guidelines require that the end user can take the battery out without damaging the battery or the device. Non-reusable fasteners should be available as spare parts. Prying a pouch cell off strong foam tape can bend or puncture it.
   - A mechanical retainer (clip, strap, frame) or stretch-release strips is the safer design. This is my reading; no Commission text mentions adhesive.
   - The July 2026 delegated act adds a derogation for wearables, but only where they are too small for a safe swap or rely on a sealed enclosure. Even then, it only lowers the bar to "independent professionals". An open board with a plug-in cell does not need or fit it.
   - Art. 11 also requires replacement cells to be available for 5 years after the last unit is placed on the market, plus removal instructions published online.
3. **CE marking and the EU declaration of conformity have been required since 18 Aug 2024** (Art. 17 and Chapter VI). The only harmonised standard listed so far is EN 18060:2025, for EV batteries (OJ, 16 Sep 2026). Having no standard for portable batteries removes the presumption of conformity. It does not postpone the obligation.
4. **Labels: three dates.**
   - The separate-collection symbol on the cell has been required since 18 Aug 2025. On a 30 × 30 mm face it must cover at least 3 %, so about 5.2 × 5.2 mm.
   - A QR code is required from 18 Feb 2027.
   - The full general-information and capacity label applies from the later of 18 Aug 2026 and 18 months after the Commission's labelling implementing act enters into force. I found only a December 2025 draft of that act, so the date is open.
5. **Other duties if on the market:**
   - EPR registration in every Member State where badges are first made available (Art. 55, from 18 Aug 2025).
   - Free take-back of waste portable batteries where we sell (Art. 62).
   - Waste information at the point of sale (Art. 74).
   - Annex I limits: mercury 0.0005 %, cadmium 0.002 %, lead 0.01 %.
   - Due diligence does not apply: it covers only operators above EUR 40 million turnover (Art. 47), and it was postponed to 18 Aug 2027 anyway.

**RED, in one line:** the badge is radio equipment under RED 2014/53/EU, whose Art. 3(1)(a) safety objective has "no voltage limit". The usual standards are EN 62368-1, EN 300 328, EN 301 489-1/-17 and EN 62311, plus EN 18031-1 for internet-capable radio equipment from 1 Aug 2025.

**GPSR:** because RED and 2023/1542 are harmonisation legislation, the General Product Safety Regulation (EU) 2023/988 applies only in part. Its general safety requirement and Art. 9–18 do not apply to risks those acts already cover. Accident notification through the Safety Business Gateway (Art. 20), distance-sale information (Art. 19) and the recall rules (Chapter VIII) do apply.

### Cited findings
**Scope and definitions** — [Regulation (EU) 2023/1542, OJ L 191, 28.7.2023](https://eur-lex.europa.eu/eli/reg/2023/1542/oj/eng) **[P]**. The consolidated text of 13 Aug 2026 lists amendments by 2024/1781, 2025/1561 and 2026/1738. 2026/1738 changes Annex I only for vehicles ([consolidated text](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:02023R1542-20260813)).
- **Art. 3(9):** a portable battery is "sealed, weighs 5 kg or less" and is not industrial, LMT, SLI or EV.
- **Art. 3(10):** general-use batteries are only the common formats (AA, AAA, 9 V and so on).
- **Art. 3(17), making available:** supply "in the course of a commercial activity, whether in return for payment or free of charge".
- **Art. 3(16):** placing on the market is the first making available in the Union.
- **Art. 3(47), producer:**
  - (a)–(c) all require that the producer "is established in a Member State". Point (c) covers anyone who supplies batteries "for the first time in that Member State on a professional basis", including batteries incorporated in appliances, from a third country.
  - (d) covers sellers in a third country, but only for distance sales to end users.
  - My reading: a Swiss team selling face to face at a camp fits none of (a)–(d). That is a gap, not an exemption, because 2019/1020 still requires an EU operator (below). A German organiser selling the badges is a producer under (c).
- **Art. 3(64):** the importer must be established in the Union.
- **Art. 3(33), manufacturer:** whoever manufactures a battery, or has it made, and markets it under their own name. For the cell, that is normally the cell factory.
- **Art. 39:** suppliers of cells must give manufacturers the information needed to comply, free of charge.

**Who must be in the EU** — [Regulation (EU) 2019/1020, Art. 4](https://eur-lex.europa.eu/eli/reg/2019/1020/oj) **[P]**
- Art. 4(1): a product under the listed acts "may be placed on the market only if there is an economic operator established in the Union".
- Art. 4(2): that operator can be an EU manufacturer, an importer, an authorised representative or a fulfilment service provider.
- Art. 4(4): its name and address go on the product, the packaging, the parcel or an accompanying document.
- Art. 4(5) lists RED 2014/53/EU, RoHS 2011/65/EU and EMC 2014/30/EU. 2023/1542 Art. 91 adds the Battery Regulation to the list ([2023/1542 Art. 91](https://eur-lex.europa.eu/eli/reg/2023/1542/oj/eng)).

**Free giveaways and hobbyists** — [Blue Guide 2022, §2.2, OJ C 247, 29.6.2022](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52022XC0629(04)) **[P]**
- Commercial activity is "providing goods in a business related context". Non-profit organisations can be in such a context.
- This "can only be appreciated on a case by case basis taking into account the regularity of the supplies, the characteristics of the product, the intentions of the supplier".
- "In principle, occasional supplies by charities or hobbyists should not be considered as taking place in a business related context."
- A gift counts as a transfer just like a sale.
- The Blue Guide is guidance. Only the CJEU interprets the law bindingly.

**Application dates** — [2023/1542 Art. 96](https://eur-lex.europa.eu/eli/reg/2023/1542/oj/eng) **[P]**
- General application from 18 Feb 2024.
- Art. 11 from 18 Feb 2027.
- Art. 17 (conformity assessment) and Chapter VI (economic operators, including Art. 38(3) on the DoC and CE marking) from 18 Aug 2024.
- Chapter VIII (EPR, registration, take-back) from 18 Aug 2025.

**Art. 11, removability and replaceability** [P]
- **Art. 11(1):** whoever places products incorporating portable batteries on the market must make the batteries "readily removable and replaceable by the end-user". The test is "commercially available tools", without specialised tools (unless supplied free), proprietary tools, "thermal energy, or solvents". Instructions and safety information must come with the product and be "made available permanently online".
- **Art. 11(6):** replaceable means a compatible battery can be fitted without affecting function, performance or safety.
- **Art. 11(7):** batteries must be available as spare parts for at least 5 years after the last unit is placed on the market.
- **Art. 11(8):** software must not block a compatible replacement.
- **Commission guidelines, [C/2025/214](https://eur-lex.europa.eu/eli/C/2025/214/oj/eng) (10 Jan 2025)** **[P]**:
  - Removal must be safe, "avoiding damage to the battery and to the device".
  - The end user is an adult "without any specific experience".
  - "Commercially available tools" includes "no tools" (EN 45554 classes).
  - The guidelines name wearables among products whose small lithium batteries cause fires at waste plants.
  - "If the fasteners are not reusable, such fasteners should also be available as spare parts."
  - The requirement does not cover products placed on the market before 18 Feb 2027.
  - They do not mention adhesive or tape.
- **[Updated guidelines C(2026) 5032](https://environment.ec.europa.eu/document/download/17491562-50cc-443a-897f-b50848ab0a8a_en?filename=C_2026_5032_1_EN_ACT_part1_v13.pdf) (14 Jul 2026)** **[P]** keep the same wording on damage and fasteners. They add §3.2.3 on wearables: the derogation applies only "if the conditions laid out in Article 11(2)(c) are met".
- **[Delegated act C(2026) 5031](https://environment.ec.europa.eu/document/download/0e738cbb-581d-42c3-bbad-83e91c066a55_en?filename=C_2026_5031_1_EN_ACT_part1_v3.pdf) (14 Jul 2026)** **[P]** replaces Art. 11(2) with eight categories. The relevant ones:
  - (c) "wearable devices for which the safety, durability, or water resistance may be compromised by user access to the battery". These must also either be "too small to allow the end-user to properly and safely handle a battery replacement" or "rely on a compact, sealed enclosure".
  - (d) electric toys, until 31 Jul 2030.
  - Recital (3) names the risk of "damage or piercing" when removing tightly encapsulated batteries.
  - A derogated product still needs a battery that independent professionals can replace.
- **Status of C(2026) 5031:**
  - The Commission sent it for scrutiny on 14 Jul 2026 ([Commission news](https://environment.ec.europa.eu/news/commission-adds-exemptions-portable-battery-removal-rules-2026-07-14_en)) **[P]**.
  - Art. 89(6) allows 3 months for objections, extendable by 2 months.
  - It enters into force 20 days after publication. I did not find it in the OJ as of 18 Oct 2026 **[U]**.
- **[Cooley, 13 Feb 2025](https://products.cooley.com/2025/02/13/european-commission-publishes-guidance-on-eu-batteries-regulation-removability-requirements/)** **[S: Cooley LLP]**: the "no damage to the battery" condition goes beyond the Regulation's text. They name pouch cells and "one-time fixings" as design problems.
- **[ElektroG § 4](https://www.gesetze-im-internet.de/elektrog_2015/__4.html)** **[P]** already asks producers to design so that end users can take batteries out "problemlos und zerstörungsfrei" (easily and without damage). § 4(4) requires information on the battery's type, chemistry and safe removal.

**CE marking, DoC and standards** [P]
- **Art. 17(1):** batteries made in series use Module A (internal production control) for Art. 6, 9, 10, 12, 13 and 14.
- **Art. 18:** the DoC follows Annex IX and is translated into the language of the market.
- **Art. 38(2)–(4):** the manufacturer draws up the technical documentation, signs the DoC, affixes CE, and keeps the papers for 10 years.
- **Art. 38(6)–(7):** the battery carries a model and batch identifier and the manufacturer's name and postal address.
- **Art. 41(2):** before placing a battery on the market, the importer must check the DoC, the technical documentation, the CE marking and the Art. 13 labels.
- **Art. 15(1):** without harmonised standards, tests must use "reliable, accurate and reproducible methods" that follow the state of the art.
- **Harmonised standards:** [Implementing Decision (EU) 2026/2048](https://eur-lex.europa.eu/eli/dec_impl/2026/2048/oj) (OJ 16 Sep 2026) is the first list. It contains only EN 18060:2025 (EV batteries). The [Commission's standards page](https://single-market-economy.ec.europa.eu/single-market/goods/european-standards/harmonised-standards/eu-battery-regulation_en) lists nothing else.
- **German fines:** missing CE is fined under BattDG § 60(2) Nr. 3, up to EUR 10,000 (section 2).

**Art. 13, labels and marks** [P]
- **13(4), from 18 Aug 2025:** the collection symbol covers at least 3 % of the largest side, at most 5 × 5 cm. Below 0.47 × 0.47 cm it moves to the packaging.
- **13(5):** "Cd"/"Pb" marking applies above 0.002 % cadmium or 0.004 % lead.
- **13(1)–(2):** the general-information label (Annex VI Part A) and, for rechargeable portable batteries, the capacity label apply "From 18 August 2026 or 18 months after the date of entry into force of the implementing act … whichever is the latest".
- **Annex VI Part A contents:** manufacturer, category and ID, place and date of manufacture, weight, capacity, chemistry, hazardous substances, "usable extinguishing agent", and critical raw materials above 0.1 %.
- **13(6), from 18 Feb 2027:** a QR code linking to the label information, the DoC and the Art. 74(1) waste information.
- **13(7):** labels and QR go on the battery, or on the packaging and documents if the battery is too small.
- **Labelling implementing act status:**
  - The Commission published a draft on 15 Dec 2025 **[S: [CIRS](https://www.cirs-group.com/en/chemicals/eu-drafts-harmonized-format-and-technical-specifications-for-battery-labeling)]**.
  - A Pryor Marking article dated Sep 2026 says the authors could not confirm publication in the OJ **[S: [Pryor](https://www.pryormarking.com/18-august-2026-and-the-eu-battery-regulation-what-the-date-actually-means/)]**.
  - I found no OJ entry **[U]**.

**EPR, take-back, waste information** [P]
- **Art. 55(2):** producers register "in each Member State where they make a battery available on the market for the first time". They may only make batteries available in that country once registered there.
- **Art. 55(7):** an authorised representative for EPR may do this. Art. 56(3) makes the representative mandatory only for producers under (47)(d), the distance sellers.
- **Art. 62(1)–(2):** distributors take back waste portable batteries free of charge at or near their outlet, with no purchase required. This is limited to categories they sell, and does not cover "waste products containing batteries".
- **Art. 74(1) and (4):** waste-battery information, including lithium safety, must be available at the point of sale.

**Substances, Annex I** [P]
- Mercury at most 0.0005 % for all batteries.
- Cadmium at most 0.002 % for portable batteries.
- From 18 Aug 2024, lead at most 0.01 % for portable batteries.

**Due diligence** [P]
- Art. 47: the chapter does not apply below "EUR 40 million" net turnover (unchanged in the consolidated text).
- [Regulation (EU) 2025/1561](https://eur-lex.europa.eu/eli/reg/2025/1561/oj/eng) (OJ 30 Jul 2025) moved Art. 48 to 18 Aug 2027.

**GPSR (EU) 2023/988** — [OJ L 135, 23.5.2023](https://eur-lex.europa.eu/eli/reg/2023/988/oj), in application since 13 Dec 2024 [P]
- **Art. 2(1):** for products under harmonisation legislation, Chapter II does not apply to risks covered by that legislation. Chapter III Section 1 (Art. 9–18), Chapters V and VII, and Chapters IX–XI do not apply at all.
- **What remains:** Section 2 (Art. 19 distance-sale information; Art. 20 accident notification "through the Safety Business Gateway"; Art. 21), Chapter IV (online marketplaces), Chapter VI (Safety Gate) and Chapter VIII (information, remedies, recalls).

**RED** [P]
- [Directive 2014/53/EU Art. 3(1)(a)](https://eur-lex.europa.eu/eli/dir/2014/53/oj): LVD safety objectives apply "with no voltage limit".
- Cybersecurity [Delegated Regulation (EU) 2022/30](https://eur-lex.europa.eu/eli/reg_del/2022/30/oj) applies from 1 Aug 2025, after [Delegated Regulation (EU) 2023/2444](https://eur-lex.europa.eu/eli/reg_del/2023/2444/oj).

---

## 2. Germany: BattDG (batteries) and ElektroG (the badge)

### Takeaway
Germany implements 2023/1542 through the **Batterierecht-Durchführungsgesetz (BattDG)** of 30 Sep 2025, in force 7 Oct 2025. It replaced the BattG.
- The Umweltbundesamt is the competent authority. stiftung ear handles the registrations.
- Since **15 Jan 2026**, every battery producer needs a registration plus membership of an approved producer responsibility organisation (*Organisation für Herstellerverantwortung*, OfH), per battery category.

The badge itself is electrical equipment under the **ElektroG**. It needs a separate stiftung ear registration (a "WEEE number") and a financing guarantee for B2C equipment. It also needs the crossed-out-bin mark with a date bar and producer identification.

**A producer with no German establishment must appoint one German authorised representative (*Bevollmächtigter*) under each law,** in writing and in German. This applies to the battery under BattDG § 40(2) and to the badge under ElektroG § 8.
- Unlike the EU battery "producer", the ElektroG producer (§ 3 Nr. 9(a)) need not be established in Germany. Making badges under our own name and offering them in Germany is enough.

**What the law does not give us:**
- **No quantity de-minimis.** Neither law has one. "Commercial activity" (*Geschäftstätigkeit*) is the only filter (ElektroG § 3 Nr. 8; EU Art. 3(17)).
- **Fines are steep.** Up to **EUR 100,000** for making batteries or equipment available unregistered. Up to EUR 10,000 for a missing Art. 11 removability, missing CE, missing German instructions or missing labels.
- **Small registry fees, unknown real costs.** The fees are EUR 16.40 per battery registration plus EUR 3.80 per quarter, and EUR 9.50 per device type plus EUR 32.80 per quarter under the ElektroG, plus EUR 50.60 to confirm a Bevollmächtigter (all net). The real costs are the representative's service, the OfH contract and the WEEE guarantee. I found no published prices for small volumes **[U]**.

**What to do, in practice.** I see three routes, in order of preference.
1. **The organiser sells the badges.** CCCV GmbH, the Berlin company behind the CCC ticket shop, sold the flow3r badge in 2023: EUR 32, battery +EUR 4.20.
   - The organiser would then be the importer and producer: ElektroG § 3 Nr. 9(c) and 2023/1542 Art. 3(47)(c).
   - We would act as the manufacturer and hand over the DoC, the cell documents and the technical file.
   - I could not check whether CCCV is registered with stiftung ear, because the register is a search form **[U]**. Ask the CCC orga.
2. **We become the producer.** We appoint a German Bevollmächtigter. It registers the badge (device type + brand) and the battery (*Gerätebatterie* + brand), joins an OfH, provides the WEEE guarantee, and reports volumes each year. Start at least 3 months ahead: the ElektroG mandate must be valid for 3 months or more, and a BattDG registration is deemed granted 12 weeks after a complete application.
3. **We treat it as non-commercial.** This only works for a free, one-off hobby giveaway. Settle it with a binding, fee-based *Feststellungsantrag* (determination application) at stiftung ear, for both the ElektroG and the battery side, before the event. Do not rely on a self-assessment for a sale of 1000 units.

### Cited findings
**BattDG** — [gesetze-im-internet.de/battdg](https://www.gesetze-im-internet.de/battdg/) **[P]**
- "Batterierecht-Durchführungsgesetz vom 30. September 2025 (BGBl. 2025 I Nr. 233)", amended 25 Nov 2025. In force 7 Oct 2025. Replaces the BattG of 25 Jun 2009.
- **§ 3 Nr. 1:** a distributor who knowingly or negligently sells batteries of unregistered producers counts as a producer itself.
- **§ 4(1):** producers may only make batteries available if they, or their Bevollmächtigter, are properly registered. § 4(3) bars distributors and fulfilment providers from handling unregistered producers' batteries.
- **§ 5(1):** register "bevor ein Hersteller Batterien … erstmals auf dem Markt bereitstellt", with brand and battery category. This holds even when an OfH is appointed. The registration is deemed granted 12 weeks after a complete application.
- **§ 6(1):** end users must hand waste batteries in separately. Batteries built into products fall under the ElektroG.
- **§ 7(1)–(2):** producers join an OfH per category, or are approved for individual take-back. They report the mass placed on the market each year.
- **§ 14(1), (3):** every distributor (*Händler*) takes back waste portable batteries free of charge at or near the point of sale. This does not extend to "Produkte mit eingebauten Altbatterien" (products with built-in waste batteries). Collected batteries go to an OfH.
- **§ 24(1)–(2):** distributors put up German-language signs, at least A4 at the entrance, saying waste batteries can be returned there.
- **§ 30:** "Zuständige Behörde … ist das Umweltbundesamt" (the competent authority is the Umweltbundesamt). § 37 lets it entrust (*beleihen*) stiftung ear.
- **§ 40(2):** producers without a German establishment must appoint a Bevollmächtigter for EPR, only one, in writing and "in deutscher Sprache".
- **§ 48:**
  - Instructions, safety information and contact details must be in German.
  - The signed DoC may be kept in German or English.
- **§ 60, fines:**
  - Making available unregistered (§ 60(1) Nr. 1): up to EUR 100,000.
  - Not registering (§ 60(2) Nr. 23): up to EUR 100,000.
  - Breaching Art. 11 (§ 60(2) Nr. 1), CE (Nr. 3), German instructions (Nr. 5) or labels (Nr. 6): up to EUR 10,000 each (§ 60(3)).
- **§ 64:** old BattG registrations had to show OfH membership by the end of 15 Jan 2026 or lapse. Registrations of producers established outside Germany did not carry over (§ 64(4)).
- No quantity threshold appears in the text. I searched for "geringfügig", "Kleinmengen", "Bagatell" and "gewerbsmäßig" without a hit.

**stiftung ear**
- [Press release, 16 Jan 2026](https://www.stiftung-ear.de/service/presse-aktuelles/neuregelungen-batterierecht-vollstaendig-in-kraft/) **[P]**:
  - The remaining battery-law provisions applied from the end of 15 Jan 2026.
  - Producers without an OfH lose their registration.
  - Selling without a registration is an administrative offence.
  - 92 % of portable-battery registrations survived the switch.
- [Fees](https://www.stiftung-ear.de/anleitungen/kosten-und-gebuehren/) **[P]** (all net, plus VAT, set by fee notice):
  - BattDG: registration (Geb. 2.1) EUR 16.40; quarterly fee (Geb. 2.2) EUR 3.80.
  - ElektroG: registration per device type (Geb. 1.1) EUR 9.50; quarterly fee (Geb. 1.2) EUR 32.80; Bevollmächtigter confirmation (Geb. 1.7) EUR 50.60 per represented company.
- Determination of the registration duty, for doubtful cases. It is binding and fee-based, filed in the ear portal with reasons:
  - [ElektroG Feststellungsantrag](https://www.stiftung-ear.de/anleitungen/weee-nummer-beantragen/feststellungsantrag/) **[P]**
  - [battery "Bescheinigung über die Registrierungspflicht"](https://www.stiftung-ear.de/de/themen/battg/hersteller-bv/registrierung/feststellungsantrag) (certificate on the registration duty) **[S: search summary of the page]**
- The [public registers](https://www.stiftung-ear.de/verzeichnisse/) list registered producers, battery producers and approved OfH. They are search forms, so I did not query them.

**ElektroG** — [gesetze-im-internet.de/elektrog_2015](https://www.gesetze-im-internet.de/elektrog_2015/), last amended 25 Nov 2025 **[P]**
- **§ 2(1) categories:** "Kleingeräte" (small equipment) and "kleine Geräte der Informations- und Telekommunikationstechnik" (small IT and telecom equipment) are both for devices with no outer dimension over 50 cm. The "Bildschirme" (screens) category starts at more than 100 cm² of screen; the badge has about 10 cm². stiftung ear assigns the device type.
- **§ 3 Nr. 8:** making available is "jede entgeltliche oder unentgeltliche Abgabe … im Rahmen einer Geschäftstätigkeit" (any supply, paid or free, in the course of a commercial activity).
- **§ 3 Nr. 9, producer:**
  - (a) whoever makes equipment under their own name "und innerhalb des Geltungsbereiches dieses Gesetzes anbietet" (and offers it in Germany). No German establishment is required.
  - (c) whoever first offers equipment from another Member State or a third country.
  - (d) distance sellers from abroad.
- **§ 4(1), (4):** design for easy, non-destructive battery removal, and inform users of the battery type, chemistry and safe removal.
- **§ 6(1)–(3):**
  - Register before placing on the market, with device type and brand, plus a guarantee (§ 7) or a B2B take-back concept.
  - No placing on the market while unregistered.
  - Show the registration number on offers and invoices.
- **§ 7(1):** an insolvency-proof annual guarantee for equipment "die in privaten Haushalten genutzt werden können" (that can be used in private households).
- **§ 8(1), (3):**
  - A producer under § 3 Nr. 9(a)–(c) without a German establishment "muss einen Bevollmächtigten beauftragen" (must appoint a representative).
  - Only one representative is allowed. The mandate must be written, "in deutscher Sprache", and valid for at least three months.
  - stiftung ear confirms the appointment.
- **§ 9:** permanent marking that identifies the producer and the date of placing on the market, plus the Annex 3 symbol (crossed-out bin). On packaging or instructions only where size requires it.
- **§ 17(1):** distributor take-back applies only from 400 m² of electrical sales area, so it does not affect a camp stall.
- **§ 45:** registration offences (Nr. 1–9) up to EUR 100,000; others up to EUR 10,000.

**What other camp badges did**
- **flow3r, Camp 2023:** an "optional add-on" reserved with the ticket for EUR 32, which "just covers our costs" ([events.ccc.de, 5 Jun 2023](https://events.ccc.de/en/2023/06/05/camp23-the-flow3r-badge/)) **[P]**. The ticket page lists "Badge 32 €" and the battery as "+4.20€". Contact is camp2023-tickets@cccv.de, and the legal notice is at legal.cccv.de ([Camp 2023 tickets](https://events.ccc.de/camp/2023/infos/tickets.html)) **[P]**.
- **CCCV:** the Congress ticket pages name the account holder as "Chaos Computer Club Veranstaltungsgesellschaft mbH (CCCV GmbH), Marienstraße 11, 10117 Berlin" ([39C3 tickets](https://events.ccc.de/congress/2025/infos/tickets.html)) **[P]**.
- So the CCC model is that the organiser's company sells the badge. Whether CCCV registered the flow3r with stiftung ear, and how card10 (2019) was handled, I could not verify **[U]**.
- **WHY2025:** krekr's write-up argues that a free, non-CE-marked giveaway is still a product put into circulation, so product-safety good practice applies ([RevSpace forum, 6 Aug 2025](https://forum.revspace.nl/raw/684/14)) **[S: forum post]**.

---

## 3. Switzerland
See [regulations_switzerland.md](regulations_switzerland.md). Not repeated here.

---

## 4. Transport (cells into CH, badges CH → DE)

### Takeaway
**(a) Bare cells.**
- A 103030 cell is **UN 3480**, even with its PCM: a single-cell battery counts as a "cell", and 3.7 Wh is under the 20 Wh small-cell limit. Installed in a badge, it is **UN 3481** "contained in equipment".
- **By air, bare cells are fully regulated.** PI 965 Section II was deleted in the 2022 DGR, so every air shipment goes under Section IA or IB. That means cargo aircraft only, a Shipper's Declaration, Class 9 and CAO labels, a trained shipper, at most 10 kg net per package, and **at most 30 % state of charge**.
- **Post is out.** Swiss Post and UPU mail do not take loose cells at all. DHL Express and UPS take them only from approved or contract accounts.
- **By road (ADR) and rail (RID), small cells are nearly exempt under special provision 188.** The cells need:
  - one inner packaging per cell, with short-circuit protection
  - a strong outer box
  - the UN 3480 lithium battery mark
  - a 1.2 m drop-test capability
  - at most 30 kg gross per package

  There is no SoC limit, no transport document and no training.
- **The precondition for every route is a UN 38.3 test summary** from the manufacturer or distributor (ADR/RID 2.2.9.1.7.1(g), required by SP 188(c)). Mass-produced cells without one have no legal transport route.
- Practical choices: an EU or Swiss stockist shipping by road, a China forwarder with a dangerous-goods sea or rail line, or air cargo with dangerous-goods paperwork.

**(b) Finished badges, CH → DE.**
- **By car or van, any number works under SP 188:**
  - each cell protected from damage and short circuit
  - each badge switched off, with an "effective means of preventing accidental activation". Our R4 off switch; tape it or use a sleeve so it cannot be bumped on.
  - strong outer boxes
  - the UN 3481 mark on every box. The unmarked exception covers only boxes with 4 or fewer installed cells and 2 or fewer boxes per consignment.

  Installed cells have no mass limit and no drop-test requirement. There is no transport document, no ADR driver training and no 1.1.3.6 counting. Switzerland applies ADR domestically (SDR Art. 4).
- **By train: avoid it.** RID itself would arguably allow SP-188-compliant boxes as luggage. But the international passenger conditions, DB's conditions and the Swiss T600 tariff limit dangerous goods to personal use, and a batch for distribution is not personal use.
- **By plane, as passengers: no.** IATA Table 2.3.A allows 15 devices per person for personal use, and items for sale or distribution are not personal use.
- **By post or courier: possible but awkward.** Swiss Post international takes at most 4 installed cells per parcel. A courier by air under PI 967 Section II allows at most 5 kg of cells per box (about 250 badges). Above 4 cells per box or 2 boxes, it needs the battery mark and an approved DHL account. Road freight under SP 188 is simpler.
- **Damaged or swollen cells never travel under SP 188.** They fall under SP 376 (damaged) or SP 377 (for disposal). Hand them in locally (section 5).

### Cited findings
**Classification and UN 38.3**
- [IATA Lithium Battery Guidance Document 2026](https://www.iata.org/contentassets/05e6d8742b0047259bf3a700bc9d42b9/lithium-battery-guidance-document.pdf) (dated 1 Jan 2026, DGR 67th ed.) **[P, paraphrased]**:
  - p. 8: cells alone are UN 3480; cells in or with equipment are UN 3481.
  - FAQ A.02: a single-cell battery is a "cell".
  - p. 9 lists the test-summary data elements.
  - C.01: the test-summary duty also applies to distributors of equipment.
  - C.05/C.06: a website or QR code is acceptable.
  - G.04: the summary need not travel with each shipment.
- [RID 2025](https://otif.org/fileadmin/docs/LegalTexts/COTIF/DangerousGoodsRID/RID/RID_2025_e_1_January_2025.pdf), SP 188, wording identical to ADR **[P]**:
  - A single-cell battery "is considered a 'cell'".
  - 2.2.9.1.7.1(g): manufacturers and subsequent distributors "shall make available the test summary" (Manual of Tests and Criteria 38.3.5). The paragraph was renumbered in 2025.
  - SP 310 (untested prototypes or production runs of 100 or fewer) is fully regulated under P910.
- 1 Jan 2020 start of the test-summary duty: [Lion Technology, Jul 2019](https://www.lion.com/lion-news/july-2019/mandatory-jan-1-lithium-battery-test-summary) **[S: Lion]**.

**IATA packing instructions 965 / 966 / 967** **[P, paraphrased]** — IATA guidance 2026, flowchart p. 10, pp. 13–16, 25–32
- **PI 965:** only Sections IA and IB remain. IB (cells of 20 Wh or less) is forbidden on passenger aircraft, limited to 10 kg per package on cargo aircraft, and needs:
  - the CAO label, the Class 9 lithium label and the battery mark
  - a Shipper's Declaration
  - full dangerous-goods training under DGR 1.5 (H.01)
- **SoC:** for PI 965 at most 30 % is mandatory; more needs State approvals (SP A331). For PI 966 (packed with equipment), at most 30 % has been mandatory since **1 Jan 2026** for cells above 2.7 Wh in Section II, and our 3.7 Wh cells are above that. For PI 967 (contained in equipment), 30 % is only recommended (p. 14).
- **PI 966/967 Section II:**
  - at most 5 kg of cells per package, on passenger or cargo aircraft
  - no mark if a consignment has no more than 2 packages with no more than 4 cells each (F.04/F.05, G.02)
  - "adequate instruction" for the shipper, not formal training (H.02)
  - since 2025, packages must be capable of a 3 m stack test ([IATA lithium page](https://www.iata.org/en/programs/cargo/dangerous-goods/lithium-batteries/))
- **PI 965 Section II was removed in the 2022 (63rd) DGR** **[S: [Lion, Aug 2021](https://lion.com/lion-news/august-2021/what-s-new-in-the-2022-iata-dgr)]**. The "8 cells / 2.5 kg / one package" figures in the question are the old Section II limits.
- **DGR 68th ed. (2027):** the [significant-changes list](https://www.iata.org/contentassets/852fbcbda9c540b893adee66e9ad81ad/dgr-68-en-significant-changes.pdf) shows no new SoC rule for PI 967 **[P, absence only]**.

**Carriers**
- [DHL Express lithium guide v2.1, from 1 Jan 2026](https://mydhlplus.dhl.com/content/dam/downloads/global/en/lithium-batteries/dhl_express_lithium_battery_guide.pdf.coredownload.pdf) **[P]**:
  - PI 965 IB needs an approved account and cargo-aircraft capacity.
  - PI 965 IA is not accepted on the road legs of TDI express in ADR countries.
  - PI 966-II needs an approved account.
  - PI 967-II with more than 4 cells per box or more than 2 boxes needs the mark and an approved account.
  - [MyDHL+ Switzerland](https://mydhl.express.dhl/ch/de/help-and-support/shipping-advice/what-can-i-ship/lithium-batteries.html): pre-approved accounts only, except small PI 967 shipments.
- [UPS operator variations, DGR ed. 66](https://www.ups.com/assets/resources/webcontent/en_US/UPS_Operator_Variations.pdf) **[P]**:
  - 5X-01: dangerous goods that need a Shipper's Declaration are accepted outside the US by contract only, 30 kg gross per package.
  - 5X-08: Section II packages show "P.I. 967-II".
  - Ed. 67 not fetched **[U]**.
- [FedEx Switzerland](https://www.fedex.com/de-ch/shipping/dangerous-goods/how-to-ship/lithium-batteries.html) **[P]**: IATA rules for air, ADR for road. Pre-approval for UN 3480 **[U]**.
- [Swiss Post, dangerous goods abroad](https://www.post.ch/de/pakete-versenden/gefahrgut/gefahrgut-ausland) **[P]**:
  - Lithium batteries are allowed only installed in a device, at most 2 batteries or 4 cells per parcel, each 20 Wh or less.
  - Loose or damaged batteries are not allowed.
  - Domestic parcels with SP 188 batteries are allowed with the paid dangerous-goods option ([Handbuch Gefahrgut, Aug 2026, §4.2.3](https://www.post.ch/-/media/portal-opp/pl/dokumente/handbuch-gefahrgut.pdf)).
- UPU: international mail takes equipment with installed cells only (4 cells or 2 batteries); loose cells are prohibited ([UPU 2011](https://www.upu.int/en/news/2011/1/yes-to-lithium-batteries)) **[S: search summary]**.
- China Post, ePacket and AliExpress "battery lines": anecdotal only **[U]**.

**ADR/RID SP 188** — [RID 2025](https://otif.org/fileadmin/docs/LegalTexts/COTIF/DangerousGoodsRID/RID/RID_2025_e_1_January_2025.pdf) pp. 3.3-2 to 3.3-3 **[P]**. The ADR 2025 text was read via the [Danish extract](https://www.brs.dk/globalassets/brs---beredskabsstyrelsen/dokumenter/forebyggelse/2025/-sp188-2025-.pdf) and the [Bavarian SV 188 leaflet, Apr 2025](https://gewerbeaufsicht.bayern.de/gefahrenschutz/doc/merkblatt_sv188.pdf) **[P]**. The English ADR on unece.org was blocked **[U]**.
- **Opening:** cells "are not subject to other provisions … if they meet the following".
- **(a)** Li-ion cell "not more than 20 Wh".
- **(c)** 2.2.9.1.7.1 (a), (e), (f) and (g) must be met.
- **(d)** Cells not installed need inner packagings "that completely enclose the cell" and a strong outer box.
- **(e)** Cells installed in equipment must be "protected from damage and short circuit", and the equipment needs "an effective means of preventing accidental activation".
- **(f)** The battery mark (5.2.1.9: "UN 3480"/"UN 3481", at least 100 × 100 mm or 100 × 70 mm, red hatched border). Exception: "no more than four cells or two batteries installed in equipment, where there are not more than two packages in the consignment". For an overpack, add "OVERPACK" in letters at least 12 mm high.
- **(g)** Cells not installed: the package withstands "a 1.2 m drop test in any orientation".
- **(h)** Cells not installed in or packed with equipment: "not exceed 30 kg gross mass".
- **Other special provisions:** SP 376 (damaged or defective), SP 377 (disposal or recycling, P909), SP 636 (collected cells to an intermediate facility).
- **Private-individual exemption 1.1.3.1(a):** covers goods "packaged for retail sale" for "personal or domestic use or for their leisure or sporting activities". A batch for distribution does not fit. SP 188 needs no such status, so this is my reading and not a problem.
- **Switzerland:** [SDR, SR 741.621, Art. 4(1)](https://www.fedlex.admin.ch/eli/cc/2002/685/de) applies ADR "auch im nationalen Verkehr" (in national traffic too) **[P]**. [RSD, SR 742.412, Art. 3](https://www.fedlex.admin.ch/eli/cc/2012/785/de) does the same for RID **[P]**.
- **ADR 2027:** applies from 1 Jan 2027, with ADR 2025 usable until 30 Jun 2027 **[S: [trans.info](https://trans.info/en/adr-2027-changes-507286)]**. A summer 2027 Camp trip may fall under either edition. No SP 188 SoC change is reported **[U against final text]**.

**Train**
- RID 1.1.2.3 and 1.1.3.8: for hand luggage only the listed exemptions apply, including special provisions such as SP 188. NOTE 1 lets carriers restrict further **[P]**.
- [GCC-CIV/PRR §7.2 (DB copy, 14 Dec 2025)](https://assets.static-bahn.de/dam/jcr:57c126ef-c328-4234-ad01-e876ba698d5a/Allgemeine%20Internationale%20Bef%C3%B6rderungsbedingngen%20%2814.12.2025%29.2025-12-05-07-23-16.pdf) **[P]**: in principle only retail-packaged items for personal, domestic, leisure or sport use.
- [CIT notice, 1 Jan 2025](https://cit-rail.org/secure-media/files/civ-products-dezemebr-2024/notice_rid_gcc_civ-prr_72_en_2025-01-01_signed.pdf) §2.4 **[P]**: excludes goods for "internal or external distribution".
- [DB Beförderungsbedingungen, 14 Oct 2026](https://assets.static-bahn.de/dam/jcr:2bcb474a-ece1-460b-84eb-eed976beefcf/Bef%C3%B6rderungsbedingungen%20der%20DB%20AG%20-%20Stand%2014.10.2026.29d458c9169edd28e3e6b4b32be8c658.pdf), Nr. 7.3.1 **[P]**: excludes dangerous goods under GGVSEB, but allows personal-use devices and loose batteries up to 100 Wh.
- [T600 (Alliance SwissPass, 15 Dec 2024)](https://www.tnw.ch/assets/images/content/T600_d.pdf) §6.1.3 and 6.2 **[P]**: hand luggage is for personal needs. Excluded items must be offloaded, with a fee of at least CHF 25. Newer edition or SBB lithium page **[U]**.

**Air travel as passengers**
- [IATA DGR 67, Table 2.3.A](https://www.iata.org/contentassets/6fea26dd84d24b26a7a1fd5788561d6e/dgr-67-en-2.3.a.pdf) **[P, paraphrased]**: devices with batteries of 100 Wh or less, at most 15 per person. Spare batteries go in carry-on only, individually protected, at most 20 per person. Larger numbers need the airline's approval.
- [IATA passenger guidance, 31 Mar 2026](https://www.iata.org/contentassets/6fea26dd84d24b26a7a1fd5788561d6e/passengers_travelling_with_lithium_batteries.pdf) **[P]**: the allowances are framed as items for personal use.
- The [DGR 68 changes](https://www.iata.org/contentassets/852fbcbda9c540b893adee66e9ad81ad/dgr-68-en-significant-changes.pdf) add a note on what "personal use" means **[P]**. ICAO's draft note says it excludes items for sale or distribution **[S: ICAO DGP/30-WP/18 via search summary]**.

---

## 5. Events: CCC rules, WHY2025, other camps, fire practice, insurance

### Takeaway
**The CCC publishes no lithium or LiPo rules** for Camp or Congress (checked: Camp 2019 wiki, Camp 2023 infos, Congress 2025 and 2026 infos). The general rules that apply:
- CERT (the Chaos Emergency Response Team) enforces fire safety.
- At Camp, the power team spot-checks equipment and turns away non-compliant gear. It warns of tents above 40 °C.
- At Congress, the organisers warn that devices can turn into smoke machines.

**40C3 moves to Hamburg Messe.** The operator's Technical Regulations 2026/27 forbid batteries and power banks as stand power. Energy-storage exhibits must be notified 4 weeks ahead, carry CE marking, be undamaged, and be protected against overheating and unattended operation. These rules are written for exhibitors, so ask the CCC orga how they apply to assemblies and a badge charging station.

**WHY2025 (Aug 2025) is the cautionary example.** The badge used two *unprotected* 18650 cells on a bare PCB, with only solder mask between the cell traces and the ground plane. A volunteer advisory told attendees never to install the cells and to run the badge from USB or a power bank. The organisers did not change the design. They epoxied the contacts and handed out a printed warning, with no recall. I found no reported fire.

**Other camps.**
- EMF (Tildagon), MCH2022, flow3r, card10 and BornHack publish battery specs and assembly notes but no safety guidance.
- MCH2022 held its pouch cell with Velcro.
- The Tildagon 2026 build added 1 mm spacing so the cell is not squashed.

**German fire-safety guidance agrees on the basics** (DGUV 205-041, bvfa/DGUV, VdS 3103, fire-brigade leaflets):
- Charge under supervision, on a non-combustible surface, away from combustibles.
- Do not charge cold cells.
- Tape the terminals of collected cells and quarantine swollen ones.
- **Water** is the extinguishing agent because it cools. CO2, ABC/BC powder and metal-fire (Class D) powder are not suitable.
- Fire blankets and covering are discouraged: covering insulates and promotes propagation (FAA).
- So-called lithium extinguishers have no test standard yet.

**Liability.** German and Swiss product-liability laws exempt products made neither for sale nor professionally. Fault-based liability remains. Swiss private liability insurance typically excludes professional activity. Ask the CCC (CCCV) and the team's insurer; I found nothing authoritative on event cover **[U]**.

### Cited findings
**CCC** **[P]**
- [Camp 2023 facilities](https://events.ccc.de/camp/2023/infos/facilities.html): generator power, RCDs, spot checks, PV rules, the heat warning, CERT. Nothing on lithium.
- [Camp 2023 survival list](https://events.ccc.de/camp/2023/infos/how-to-survive.html): bring a fire extinguisher, a water bucket or a fire blanket.
- [Camp 2023 FAQ](https://events.ccc.de/camp/2023/infos/faq.html): empty batteries can be dropped at the infopoint.
- [Camp 2019 power page](https://events.ccc.de/camp/2019/wiki/Static:Power): the same rules and heat note.
- [39C3 fundamentals](https://events.ccc.de/congress/2025/infos/fundamentals-and-faq.html) and [40C3 fundamentals](https://events.ccc.de/congress/2026/infos/fundamentals-and-faq/): the smoke-detection warning, no vaping, scooters discouraged. Nothing on batteries.
- events.ccc.de/camp/2027/ returns 404.

**Hamburg Messe (40C3 venue)** **[P]**
- [HMC Technical Regulations 2026/2027, valid from 1 Aug 2026](https://www.windenergyhamburg.com/fileadmin/general/pdf/guidelines/hmc_technische_richtlinien_aktuell_en.pdf):
  - §6.3.1: no batteries, power banks or generators as stand supply; energy-storage exhibits notified 4 weeks ahead.
  - §5.4.1.1: no e-scooters in the aisles.
  - §1.2: a guest organiser may tighten the rules.
- [HMC energy-storage leaflet 06/2026](https://www.hamburg-messe.de/fileadmin/general/pdf/technical-bulletins/de/hmc_merkblatt_energiespeichersysteme_de_en.pdf): CE, sound condition, protection against overheating and unattended operation. Contact ops@hamburg-messe.de.
- [HMC house rules, Nov 2025](https://www.hamburg-messe.de/fileadmin/general/pdf/terms-and-conditions/hmc_hausordnung_de.pdf): no battery clause.

**WHY2025 advisory** — [wiki.why2025.org/Badge/Fire_hazard](https://wiki.why2025.org/Badge/Fire_hazard) **[P, paraphrased]**. Created 5 Aug 2025 by Juerd, last edited 1 Aug 2026; the event ran 8–12 Aug 2025.
- **The problem:** two parallel, unprotected 18650 cells, handed out without a case.
- **The board layout:** cell "+" and "−" traces lay about 0.4 mm from the ground plane, separated only by 10–30 µm of solder mask. This hazard existed even with the badge off.
- **The test:** with a 20 A supply, a MOSFET glowed yellow-hot.
- **The holder:** pads were sized for a different holder, so a tab could overlap ground. The polyfuses protected only the circuit downstream.
- **The comparison:** SHA2017 and MCH2022 had shipped *protected* pouch cells with Kapton-insulated protection boards.
- **The advice:** never install the cells; return them to the Badge tent, or keep them in a sturdy non-conductive enclosure such as a power bank. USB power is probably safe. The advisory itself puts it as "Never have the 18650 cells installed in the WHY2025 badge".
- **The lessons:** a bare PCB worn on the body gets damaged; solder mask is not insulation unless it is itself protected; badges need a safety review.
- **The timeline:** problems were found on 17 Jul 2025 and the organiser (IFCAT) was told the same day. The advisory was published 5 Aug 2025.
- **The organiser's response** ([quoted on RevSpace forum](https://forum.revspace.nl/raw/684/3)) **[S: forum]**: production had started; the contacts would be covered with UV epoxy; do not charge unattended in a tent; a power bank is fully supported. The organiser's own post (why2025.org/post/822) now shows "Post Not Found".
- **Press coverage:** epoxy on the contacts, a warning with each badge, no badges for children under 7 ([Tweakers, 7 Aug 2025](https://tweakers.net/nieuws/237844/hackersconferentie-why-waarschuwt-voor-mogelijk-brandgevaar-in-badges.html)) **[S: Tweakers]**. The [WHY2025 Badge page](https://wiki.why2025.org/Badge) warns about uncured epoxy and says every badge got a visual QC **[P]**.

**Other badges** **[P]**
- [Tildagon replacing parts](https://tildagon.badge.emfcamp.org/using-the-badge/replacing-parts/): 2000 mAh LiPo, at most 64 × 40 × 7 mm.
- [Tildagon 2026 assembly](https://tildagon.badge.emfcamp.org/using-the-badge/tildagon-assembly/): 11 mm standoffs so the cell is not squashed.
- [MCH2022 getting started](https://badge.team/docs/badges/mch2022/getting-started/): pouch cell on Velcro; notes that one side tends to bulge.
- [flow3r assembly](https://docs.flow3r.garden/badge/assembly.html): a metal battery cover.
- [card10 hardware](https://card10.badge.events.ccc.de/hardware/): 200 mAh cell.
- [BornHack 2026 FAQ](https://badge.team/docs/badges/bornhack-2026/faq/): firmware stops below 3.0 V.
- DEF CON **[U]**.

**Fire-safety practice**
- [DGUV Information 205-041 (Feb 2024)](https://publikationen.dguv.de/widgets/pdf/download/article/4668) **[P, paraphrased]**:
  - Charge on a non-combustible surface, not below 0 °C, preferably supervised. Do not cover chargers.
  - Damaged cells go to a safe place.
  - Only water (possibly with additives) cools enough. Metal-fire powder or CO2 listed as suitable is an error.
  - Lithium extinguishers do not rule out self-endangerment, and there is no test standard.
  - Store at 40–60 % SoC and 0–45 °C, with taped terminals and 2.5 m clearance.
  - At collection points: separate swollen cells, use non-conductive containers with water or vermiculite, never in escape routes, supervised.
- [bvfa/DGUV extinguishing notes (22 Sep 2021)](https://www.dguv.de/medien/inhalt/praevention/fachbereiche_dguv/fb-fhb/brandschutz/sicherheitshinweise_loeschen_lithium_ionen_akkus.pdf) **[P]**:
  - Use water extinguishers, spray setting, from at least 1 m.
  - Powder and CO2 must not be used.
  - Expect re-ignition: keep the battery in water or a container afterwards.
- [VdS 3103 (2016 edition, as hosted by safetycenter.ch)](https://www.safetycenter.ch/sites/default/files/2020-11/Lithium-Batterien.pdf) **[P, older edition]**: Li-ion of 100 Wh or less is "low power". Prevent shorts, keep out of the sun, remove damaged cells, and store only UN 38.3-tested cells. The current edition, 2019-06, was not read **[U]**.
- [LFV Sachsen BSM 11](https://lfv-sachsen.de/wp-content/uploads/BSM-11-Braende-verhindern-Handhabung-Lithium-Ionen-Akkus.pdf) **[P]**: put swollen cells in a non-combustible pot, flood with water, close for days.
- [Swiss BfB leaflet](https://www.bfb-cipi.ch/fileadmin/user_upload/bfbcipi/Dokumente/Merkblaetter/bfb-merkblatt-akkus.pdf) **[P]**: no unattended or overnight charging, not in escape routes, smoke detectors where charging happens.
- [FAA SAFO 09013](https://www.faa.gov/sites/faa.gov/files/other_visit/aviation_industry/airline_operators/airline_safety/SAFO09013.pdf) **[P]**: "Do not cover the device or use ice to cool the device".
- [FAA DOT/FAA/TC-24/39 (Dec 2024)](https://www.fire.tc.faa.gov/pdf/tc24-39.pdf) **[P]**: containment bags varied in performance at 30–154 Wh, and some tore from gas build-up. One 3.7 Wh cell per bag is a much easier case (my reading, not tested).
- ISO 3941:2026 introduces fire Class L for lithium-ion **[S: [FPA, 8 Feb 2026](https://www.thefpa.co.uk/fire-and-risk-management-journal/news/Class%20L%20introduced%20for%20lithium-ion%20battery%20fires)]**. No Class L extinguisher approvals found **[U]**.
- The [MVStättVO](https://www.is-argebau.de/Dokumente/4231724917250.pdf) makes the venue operator responsible for safety (§38) and requires a fire watch (§41) and fire-safety rules (§42) **[P]**.

**Liability and insurance**
- [ProdHaftG §1(2) Nr. 3](https://www.gesetze-im-internet.de/prodhaftg/__1.html) **[P]**: no strict liability for products made neither for sale nor in a professional activity.
- [Swiss PrHG Art. 5(1)(c)](https://www.fedlex.admin.ch/eli/cc/1993/3122_3122_3122/de) **[P]** has the same exemption.
- Fault-based liability (BGB §823, OR Art. 41) still applies.
- Swiss Privathaftpflicht typically excludes professional activity **[S: [comparis.ch](https://www.comparis.ch/hausrat-versicherung/privathaftpflicht/tipps)]**.

---

## 6. Cell safety standards and supplier documents

### Takeaway
**The standards that apply.**
- **IEC 62133-2:2017+AMD1:2021** is the safety standard for portable lithium cells and batteries. Clause 5.4 says the battery must be designed to keep the cell inside its temperature, voltage and current limits, and the charger must do the same.
- **IEC 62368-1 Annex M** applies to the badge as end product. M.4.2 requires charging to stop above the highest specified charging temperature, under normal, abnormal and single-fault conditions.
- **UN 38.3** (tests T.1–T.8) is a transport test, not a use-safety test.
- **UL 2054 / UL 1642** are the US equivalents. UL 1642 still appears active; UL 62133-2 is the US adoption of IEC 62133-2.

**The TEMP pin is a gap.** With TEMP tied to GND the TP4056 has no charge-temperature cut-off, and a DW01-class PCM protects only voltage and current. So the current badge cannot meet M.4.2. The NTC in DESIGN.md §5 hazard 3 fixes that.

**EU harmonisation.** EN 62133-2 is not in the LVD harmonised list; EN 62368-1 is. Under RED, the safety objective applies without a voltage limit.

**Documents to demand before paying:**
1. A UN 38.3 test summary for the exact model.
2. An IEC 62133-2 CB test certificate plus the full CB test report, checked in the IECEE database. The model, maker, factory, ratings and edition must match.
3. A cell datasheet with charge temperature range and maximum charge current.
4. The PCM specification: overcharge, over-discharge, over-current and short-circuit thresholds and delays.
5. An SDS. It is a hazard sheet, not proof of testing.
6. For cells that will be on the EU market: the EU DoC under 2023/1542, CE marking and the collection symbol on the cell.

**Red flags:** a report for a different model or capacity, a cell-only report for a cell+PCM "battery", or an SDS offered instead of test reports. Transport Canada found that half of the third-party battery sets it bought online failed UN 38.3. The sellers often had no test summary.

### Cited findings
**IEC 62133-2**
- [IEC 62133-2:2017+AMD1:2021 CSV](https://webstore.iec.ch/en/publication/70017), published 15 Jul 2021 **[P]**.
- From the [preview PDF](https://cdn.standards.iteh.ai/samples/21479/fc1425401c494ac88927998737150b9b/IEC-62133-2-2017.pdf) **[P, paraphrased]**:
  - 5.4 covers design within the cell's limits and charger instructions.
  - 5.5 covers terminals.
  - The tests include continuous charge, high-temperature case stress, external short circuit, free fall, thermal abuse, crush, overcharge, forced discharge and forced internal short.
  - Annex A sets the charge temperature and voltage ranges.
- Listed in the IECEE CB scheme **[S: [IECEE page](https://www.iecee.org/certification/iec-standards/iec-62133-22017amd12021)]**.

**IEC 62368-1:2023 Annex M**
- [Table of contents](https://cdn.standards.iteh.ai/samples/105662/f150bf464ae443b08a9b283a8a80c50c/IEC-62368-1-2023.pdf) **[P]**: M.3 protection circuits; M.4 secondary lithium (M.4.2 charging safeguards, M.4.3 fire enclosure, M.4.4 drop); M.5 short circuit while carrying; M.6 short-circuit safeguards.
- [UL Q&A](https://www.ul.com/resources/iec-62368-1-ask-engineers-question-and-answer-page) **[P, paraphrased]**: charging stops above the specified temperature (M.4.2.3), and cell limits hold under single faults (M.4.2.1).

**TP4056 and PCM**
- [TP4056 datasheet](https://dlnmh9ip6v2uc.cloudfront.net/datasheets/Prototyping/TP4056.pdf) **[P]**:
  - Charging pauses when TEMP is outside 45–80 % of VIN. Grounding TEMP disables the function.
  - Float voltage 4.2 V ±1.5 %.
  - The thermal regulation protects the chip, not the cell.
- [DW01-P datasheet](https://cdn.sparkfun.com/assets/learn_tutorials/2/5/1/DW01-P_DataSheet_V10.pdf) **[P]**: overcharge trip 4.25 V ±50 mV, over-discharge 2.40 V, over-current 150 mV across the MOSFETs, no temperature input.
- Typical 1000 mAh LiPo datasheet ([ZONCELL LP402764](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/196/DataSheet_2D00_LP402764_2D00_1000ZHL.pdf)) **[P, for that cell]**: charge 0–45 °C, standard charge 0.2C, maximum 1C. Our 400 mA is 0.4C. The chosen supplier's datasheet is what counts.

**EU listing**
- [LVD Decision (EU) 2023/2723](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32023D2723) **[P]**: lists EN 62368-1, does not list EN 62133-2.
- Whether either is cited under RED **[U]**.

**UN 38.3 summary contents**
- [49 CFR 173.185(a)(3)](https://www.ecfr.gov/current/title-49/subtitle-B/chapter-I/subchapter-C/part-173/subpart-E/section-173.185) **[P]** mirrors Manual 38.3.5:
  - manufacturer and test lab with contact details
  - unique report ID and date
  - cell or battery description, with mass, Wh and model
  - tests passed
  - UN Manual edition
  - a signatory's name and title
- The UN lettering itself was not fetched **[U]**.
- Test list T.1 altitude to T.8 forced discharge **[S: [Intertek](https://www.intertek.com/blog/2019/04-25-battery/)]**.

**Checking a CB certificate**
- [IECEE CB certificates](https://www.iecee.org/certification/cb-test-certificates) **[P]**: every CB certificate is in the online database at certificates.iecee.org. The public view is an extract, and the full certificate comes from its holder.
- [Authorised signatories list](https://www.iecee.org/certification/authorized-cbtc-signatories) **[P]**.

**Red flags**
- [Transport Canada, Mar 2023](https://tc.canada.ca/sites/default/files/2023-03/Research-summary-Evaluation-analysis-substandard-lithium-ion-batteries-UN-38.3-testing.pdf) **[P]**:
  - All 4 OEM sets passed UN 38.3; 10 of 20 third-party sets failed, at T.3, T.5 and T.7.
  - Sellers could not supply a summary, did not know what one was, or supplied one that did not match.
  - 16 of 24 shipments were mis-marked or mis-packed.
- bvfa/DGUV (above): manufacturers' SDSs are often too generic on extinguishing agents.

---

## What this means for the Herz badge

Ordered by deadline. **R** = required (by law, if the condition holds); **Rec** = recommended. "If on the market" means a badge supplied in the course of a commercial activity in the EU (section 1); a free one-off hobby giveaway may fall outside, and that has not been settled.

**Before buying cells**
1. **R.** Get a UN 38.3 test summary for the exact cell model. Without it, cells cannot legally travel by road, rail or air. Sources: ADR/RID 2.2.9.1.7.1(g) and SP 188(c); IATA guidance C.01.
2. **Rec.** Get an IEC 62133-2 CB certificate plus the full report, checked on certificates.iecee.org, and the datasheet (charge 0–45 °C, maximum charge current of 0.4C or more) and PCM specification. Sources: IECEE; IEC 62133-2 §5.4; DESIGN.md D18.
3. **R if on the market.** The cell carries the crossed-out-bin symbol (at least about 5.2 × 5.2 mm on a 30 × 30 mm face), its maker's name and address, and a model and batch ID. The supplier provides an EU DoC under 2023/1542 and the CE mark, and confirms the Annex I limits. Sources: Art. 13(4), 38(3), (6), (7), 41(2), Annex I.
4. **R if on the market from 18 Feb 2027 (Camp 2027).** A QR code on the cell, or on the packaging and documents if the cell is too small. Source: Art. 13(6)–(7).
5. **R.** Choose a transport route that accepts UN 3480:
   - road under SP 188 from an EU or Swiss stockist, or
   - a forwarder with a dangerous-goods sea or rail service, or
   - air cargo under PI 965 IB: cargo aircraft only, a Shipper's Declaration, at most 30 % SoC, at most 10 kg per package.

   Not Swiss Post or ordinary mail. Sources: SP 188; IATA PI 965; Swiss Post; UPU.
6. **R (CH).** Swiss import duties, the INOBAT disposal fee and Swiss labelling: see [regulations_switzerland.md](regulations_switzerland.md).
7. **Rec.** Decide now who places the badges on the EU market: CCCV, a German club, or our own Bevollmächtigter. Their name and address go on the badge or its packaging. Sources: 2019/1020 Art. 4(1), (4); ElektroG § 8; BattDG § 40(2).

**Before building (hardware and paperwork)**
1. **R for units placed on the market from 18 Feb 2027.** End-user removable and replaceable cell.
   - Keep the JST plug.
   - Replace strong foam tape with a mechanical retainer (clip, strap, frame) or stretch-release strips that a layperson can undo without heat, solvent or prying the pouch.
   - Publish removal instructions online.
   - Keep compatible spare cells, and spare fasteners if they are not reusable, available for 5 years.
   - Sources: Art. 11(1), (6), (7); C/2025/214; C(2026) 5032; ElektroG § 4. For 40C3 (Dec 2026) this is **Rec**.
2. **Rec, effectively R for a RED/EN 62368-1 claim.** NTC on the TP4056 TEMP pin (DESIGN.md §5 hazard 3). Sources: IEC 62368-1 M.4.2; IEC 62133-2 §5.4; TP4056 datasheet.
3. **Rec.** The 2 A fuse, the insulating sheet and the spacer from DESIGN.md §5 (D18, D19). Lessons from WHY2025 and Tildagon: keep bare traces off the cell, and do not let the cell be squashed.
4. **R if on the market.** RED technical file and CE on the badge (EN 62368-1, EN 300 328, EN 301 489-1/-17, EN 62311, EN 18031-1 if internet-capable), plus RoHS. Sources: RED Art. 3; 2022/30.
5. **R if on the German market.** On the badge, or on packaging or leaflet if too small:
   - crossed-out bin with date bar and producer ID
   - battery type, chemistry and safe-removal note
   - German instructions and safety information

   Sources: ElektroG § 9 and § 4(4); BattDG § 48; Art. 11(1).

**Before the event (start at least 3 months ahead)**
1. **R if on the German market.** Registrations by the German seller or our Bevollmächtigter:
   - ElektroG registration (device type + brand) with the B2C guarantee
   - BattDG registration (*Gerätebatterie* + brand) with OfH membership
   - registration number on offers and invoices

   Sources: ElektroG § 6–8; BattDG § 4, 5, 7, 40; stiftung ear fees.
2. **Rec if we claim non-commercial status.** A binding *Feststellungsantrag* at stiftung ear (ElektroG and batteries). Source: stiftung ear.
3. **R.** Pack for the car or van under SP 188:
   - badges switched off, with the switch secured
   - each badge protected (sleeve or divider)
   - strong boxes, each with a UN 3481 mark
   - a copy of the UN 38.3 summary in the car (Rec)

   Not by train with the batch, not as passenger baggage on a plane. Sources: SP 188(e), (f); GCC-CIV/PRR 7.2; DB 7.3.1; T600; IATA Table 2.3.A.
4. **Rec.** Agree a charging point with the CCC orga or CERT. For 40C3, check whether the HMC energy-storage notification (4 weeks ahead) applies. Sources: HMC Technical Regulations §6.3.1; HMC leaflet.
5. **Rec.** Check insurance: ask CCCV whether its event liability cover includes our badges, and ask the team's insurers about the private-liability exclusion for professional activity. Sources: ProdHaftG §1(2); PrHG Art. 5; comparis.

**At the event**
1. **Rec.** Charging station:
   - supervised, on a non-combustible surface
   - out of the sun (tents reach 40 °C or more, cells charge only up to 45 °C)
   - no cold cells (Congress)
   - not in escape routes, nothing covered

   Sources: DGUV 205-041; BfB; CCC Camp power page.
2. **Rec.** Fire kit: a water extinguisher or bucket of water (spray from at least 1 m), and a metal box with sand or vermiculite for a hot cell. No CO2, powder or Class D. No blanket as the main tool. Sources: bvfa/DGUV; DGUV 205-041; FAA SAFO 09013.
3. **Rec.** Collection box for damaged or swollen cells: terminals taped, separate non-conductive container, supervised. Swollen cells go into water or sand in a non-combustible pot. Sources: DGUV 205-041 §6.6; LFV Sachsen.
4. **R if we sell (we are then a distributor).** Free take-back of waste portable batteries at the stall, a German sign (A4 or larger), waste information, and hand-over to an OfH. Sources: Art. 62, 74(4); BattDG § 14, § 24.
5. **R if on the market.** Report any accident with injury through the EU Safety Business Gateway. Source: GPSR Art. 20.

**After the event**
1. **R.** Damaged cells never go home in the car under SP 188 (SP 376/377). Hand them in locally in Germany: an OfH/GRS collection point, a municipal *Wertstoffhof* (recycling yard), or the Camp infopoint. Sources: RID/ADR SP 376, 377; BattDG § 15; Camp 2023 FAQ. For the Swiss and German routes, see regulations_switzerland.md.
2. **R if on the market.** Report annual volumes (BattDG § 7(2); ElektroG § 27). Notify stiftung ear when stopping (Art. 55(12); ElektroG § 6(1)). Keep the DoC and technical file for 10 years (Art. 38(4)).
3. **R for units placed on the market from 18 Feb 2027.** Spare cells available for 5 years after the last badge (Art. 11(7)).

---

## Could not verify
- Whether delegated act C(2026) 5031 (new Art. 11(2) derogations) has been published in the OJ or is in force.
- Whether the labelling implementing act under Art. 13(10) has been adopted or published, so the date of the general-information and capacity label is open.
- Whether CCCV GmbH is registered with stiftung ear for ElektroG or batteries, and how the flow3r and card10 badges were registered (the register is a search form, not queried).
- Prices for a German Bevollmächtigter, OfH membership and the WEEE guarantee at 100–1000 units.
- Whether stiftung ear or the UBA has published a position on free hobby giveaways or non-profit event badges. I found only the general *Geschäftstätigkeit* test.
- Whether EN 62133-2 or EN 62368-1 is cited in the OJ under RED.
- English ADR 2025 text on unece.org (blocked). I used RID 2025 plus the Danish and Bavarian ADR extracts. The final ADR 2027 SP 188 wording.
- UPS edition 67 variations and FedEx Europe pre-approval for UN 3480. China Post, ePacket and AliExpress battery lines.
- Current VdS 3103:2019 text; ISO 3941:2026 primary text; effectiveness of AVD, F-500 or Lith-Ex extinguishers.
- The IFCAT (WHY2025) statement itself (the post was removed); any actual WHY2025 fire.
- Any CCC page on LiPo or charging, and Camp 2027 dates and rules (not announced).
- Event and product liability insurance terms.
- Interpretation: whether a cell unplugged from its JST but still taped in the badge counts as "contained in" equipment (PI 967) or "packed with" it (PI 966, where 30 % SoC is mandatory by air).
