# Asian LiPo cell makers selling direct for the battery badge (state: October 2026)

Scope: which Chinese cell makers can sell a single-cell LiPo pouch of about 1000 mAh (103030 class, with PCM and a JST PH lead) to a Swiss hobby team at 10, 100 and 1000 pieces, how reputable each one is, what the cell really holds, how lithium cells get from China to Switzerland, and what it costs landed. Swiss and European distributors are covered in a separate note. Facts come from the supplier pages and listings linked in each line. "Est." marks my own estimates and arithmetic. Prices are "as listed 2026-10-17" (pages read on 17 and 18 October 2026). Currency: 1 USD = 0.824 CHF and 1 CNY = 0.1232 CHF, cross rates from the [ECB reference rates of 16 October 2026](https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html).

Project facts used below (read from the repo, not from the web): the board is 30 × 34 mm and the cell sits flat behind it without overhang (`herz_badge/DESIGN.md`). The TP4056 charges to 4.2 V at 400 mA. The load is 130–230 mA typical, with peaks of about 1.2 A (firmware cap about 0.8 A). The cell needs a PCM and a JST PH 2.0 plug with pin 2 = + and pin 1 = GND (footprint JST S2B-PH-SM4-TB, `herz_badge/BOM.md`). The BOM lists a 103030 1000 mAh cell from Huizhou Jiaxinrui, Shenzhen WLY or Dongguan Mozhong at CHF 0.68–1.19 before shipping.

---

## Q1. What a "103030" really is: size with PCM, honest capacity, discharge

### Takeaway
A 103030 with its PCM folded on the top seal measures about 10.5 × 30.5 × 32–33 mm. It fits the 34 mm length, but at 30.5 mm it is 0.5 mm wider than the board. Factories that publish full datasheets rate this size at **800–900 mAh, not 1000 mAh**. The 1000 mAh listings on Alibaba give weights of 13–15 g, which would need about 250–285 Wh/kg. That is at or above Grepow's best stacked cells, so the 1000 mAh label is almost certainly inflated. The 35 mm long sizes (103035, 903035, 803035) come to **37 mm with the PCM** and do not fit. Every candidate cell is rated 1C continuous (0.8–0.9 A), with PCM over-current trips at about 2.5–5 A. That covers the firmware's 0.8 A cap, and the 1.2 A peaks only as short pulses. Two narrower cells avoid the overhang: LiPol's LP962830 (28 mm wide, 850 mAh) and the 902530 class (25 mm, about 600–700 mAh, below the 800 mAh minimum).

### Cited findings

**Length with PCM (what the drawings show):**
- A 903035 datasheet from DNK Power (fpbattery.com) gives cell length L = 35 mm, L1 = 37 mm and body length with PCM BL = 37 ± 1 mm, at T = 9 mm and W = 30 mm. Its PCM trips at 4.275 V ± 50 mV over-charge, 2.5 V ± 50 mV over-discharge and 3–5 A over-current. Max continuous discharge is 1C and pulse discharge is 3C for 10 ms — [DNK/fpbattery 903035 datasheet](https://www.fpbattery.com/wp-content/uploads/2024/06/fpbattery-903035-3.7V-1000mAh-Lithium-Polymer-Battery-Specification.pdf).
- Shenzhen Data Power (DTP) publishes "MAX size" for each model: DTP503030 is 5.2 × 30.5 × 32 mm, DTP103035 is 10.2 × 30.5 × 37 mm, and DTP103040 (1200 mAh) is 10.2 × 30.5 × 42 mm — [DTP listing on Made-in-China](https://dtpbattery.en.made-in-china.com/product/bOGJsaSlgUcn/China-1000mAh-3-7V-103035-Super-Thin-Li-ion-Square-Lipo-Battery-for-Baby-Monitor.html).
- BENZO/Ufine's UFX 903030 lists maximum pack dimensions of 9 × 30 × 32 mm — [bzbattery.com UFX 903030](https://www.bzbattery.com/high-power-rechargeable-lipo-battery-for-prenatal-education-instrument-ufx-903030-800mah-3-7v-li-polymer-battery.html). BENZO's 803035 is listed as 8 × 30 × 37 mm — [benzoenergy.com BZ 803035](https://www.benzoenergy.com/china-lithium-battery-manufacturer-odm-battery-for-walkie-talkie-bz-803035-800mah-3-7v-kc-certification-lipo-battery.html).
- LiPol lists LP103035 as "10×30×36mm" in one table and 10 × 30 × 35 mm in another — [lipobatteries.net LP103035](https://www.lipobatteries.net/hot-selling-lipo-battery/lp103035-1000mah-cb-3-7v-lipo-battery/). Its sister site gives 10.0 × 30 × 36 mm "with a protection circuit and wires" — [lipo-battery.com LP103035](https://lipo-battery.com/3-7v-rectangle-lipo-battery-lp103035-1000mah/).

**Capacity that reputable makers give for this volume:**

| Cell | Maker | Size (mm) | Capacity | Weight | Source |
|---|---|---|---|---|---|
| LP603030 | EEMB | 6 × 30 × 30 | 480 mAh | 9.6 g | [eemb.com standard list](https://www.eemb.com/products-55) |
| LP103042 | EEMB | 10.3 × 30.5 × 44 | 1250 mAh | — | [eemb.com standard list](https://www.eemb.com/products-55) |
| AS603030 | A&S Power | 6 × 30 × 30 | 520 mAh | — | [HKTDC listing](https://www.hktdc.com/event/hkelectronicsfairae/tc/product/1X1J0GBD) |
| UFX 903030 | BENZO / Ufine | 9 × 30 × 32 max | 800 mAh min, 820 typ | 17 g | [bzbattery.com](https://www.bzbattery.com/high-power-rechargeable-lipo-battery-for-prenatal-education-instrument-ufx-903030-800mah-3-7v-li-polymer-battery.html) |
| Ufx103030 | Ufine | 10 × 30 × 30 | 850 mAh | — | [Made-in-China listing](https://www.made-in-china.com/price/prodetail_Lithium-Battery_iphRnXlCbscf.html) |
| 103030 | WLY (Wiliyoung) | 10 × 30 × 30 | 900 mAh | 18 g | [Alibaba listing](https://www.alibaba.com/product-detail/OEM-ODM-900mah-Lithium-Polymer-Battery-1600689544384.html) |
| LP103030 | SCE | 10 × 30 × 30 | 900 mAh | 18 g | [Alibaba listing](https://www.alibaba.com/product-detail/103030-3-7V-900mAh-Lithium-Ion_1601590784925.html) |
| LP962830 | LiPol | 9.6 × 28 × 30 | 850 mAh | — | [lipobatteries.net 800 mAh table](https://www.lipobatteries.net/lipo-batteries-800mah/) |
| LP902929 | LiPol | 9 × 29 × 29 | 700 mAh | — | same page |
| 103030 "LUNKE" | Dongguan Mozhong | 10 × 30 × 30 | **1000 mAh** | 13 g / 15 g | [listing A](https://www.alibaba.com/product-detail/103030-3-7V-1000mAh-Rechargeable-LiPo_10000030919461.html), [listing B](https://www.alibaba.com/product-detail/103030-3-7V-1000mAh-High-Capacity_1601668524434.html) |

- Grepow says its stacked pouch cells reach "high energy density up to 275wh/kg" — [grepow.com LiPo](https://www.grepow.com/lipo-battery.html).
- Est.: EEMB's LP603030 holds 1.78 Wh in 9.6 g, about 185 Wh/kg. WLY's 103030 holds 3.33 Wh in 18 g, also about 185 Wh/kg. Mozhong's "1000 mAh" (3.7 Wh) in 13 g would be 285 Wh/kg, and in 15 g 247 Wh/kg. Scaling EEMB's LP103042 by active length ((30 − 4) / (44 − 4) × 1250 mAh) gives about 810 mAh for a 103030. Plan on 800–900 mAh.

**Discharge and PCM figures published for candidate cells:**
- Ufine 103035 and 803035: max discharge 1C (1100 mA and 800 mA). PCM over-charge 4.28 V ± 50 mV (release 4.08 V), over-discharge 2.4 V ± 100 mV (release 3.0 V), over-current 2.5–4.5 A with a 5–10 ms delay, NTC "No" — [Ufine 103035](https://www.ufinebattery.com/products/3-7-v-1100mah-lithium-ion-battery-103035/), [Ufine 803035](https://www.ufinebattery.com/products/3-7-v-800mah-lithium-ion-battery-803035/). The same 103035 page also claims "a maximum discharge rate of 5.0C", which contradicts its own 1100 mA table.
- WLY 103030: max discharge 1.0C / 900 mA, max charge 1.0C / 900 mA, standard 0.5C — [WLY listing](https://www.alibaba.com/product-detail/OEM-ODM-900mah-Lithium-Polymer-Battery-1600689544384.html).
- BENZO UFX 903030: max continuous discharge 1C, internal impedance ≤ 115 mΩ at 1 kHz — [bzbattery.com](https://www.bzbattery.com/high-power-rechargeable-lipo-battery-for-prenatal-education-instrument-ufx-903030-800mah-3-7v-li-polymer-battery.html).

### Inferences
- The 400 mA TP4056 charge is 0.44–0.5C for an 800–900 mAh cell, inside every listed standard-charge figure (0.2–0.5C).
- At the 0.8 A firmware cap an 800 mAh cell runs at 1C, which is its continuous rating. The 1.18 A white flash (150 ms on, 150 ms off) is about 1.5C in pulses, well below the 2.5 A minimum PCM trip. Ask for a 2C rating if the flash effects stay.
- The 0.5 mm width overhang of a 30.5 mm cell is cosmetic, but it is not "no overhang". LP962830 (28 mm) is the only fitting cell found that is narrower and still at about 850 mAh.
- The DESIGN.md runtime table assumes 1000 mAh. With a real 850–900 mAh cell, all runtimes shrink by 10–15 %.

### Gaps
- No maker publishes a 103030 drawing with PCM and lead exit. Ask for the drawing before ordering, and specify the lead exit side.

---

## Q2. Who the makers are: factory or trader, certificates, red flags

### Takeaway
The best-documented makers (Grepow, EEMB) do not sell a standard 103030. Grepow makes them to order. EEMB's nearest cells are a 480 mAh 603030 and a 44 mm long 103042. Of the makers that do list a fitting cell, three show real factory evidence. **Guangdong Ufine / BENZO** has its own cell plant in Jiangmen and publishes PCM specs. **Shenzhen Data Power (DTP)** is BV-audited and publishes maximum dimensions. **Shenzhen WLY Electronics (Wiliyoung)** is SGS-verified, with 8,000 m² and 139 staff, and lists an honest 900 mAh. Of the three shortlisted Alibaba sellers, WLY is a credible manufacturer. **Dongguan Mozhong (LUNKE)** was founded in 2024, lists "21 collaborating factories", and its listing attributes are copy-paste ("semi-solid state", e-bikes, power tools); treat it as a trader with an inflated rating. **Huizhou Jiaxinrui (JXR)** is a real, verified Alibaba seller, but its listings contain implausible claims. No maker shows a model-specific UN38.3 summary or IEC 62133-2 CB report on a public page, so these must be requested. None publishes an EU Battery Regulation 2023/1542 declaration for small cells.

### Cited findings

**Comparison table:**

| Maker (site) | Since / type | Management certificates | Product certificates shown | Third-party audit / platform | Distribution | Red flags |
|---|---|---|---|---|---|---|
| Grepow, Shenzhen ([grepow.com](https://www.grepow.com/about-us.html)) | 1998; 4 factories, 250,000 m², about 3,500 staff; offices in DE and US | ISO 9001 (1999), ISO 14001 (2004), ISO 45001, IATF 16949 (2016), ISO 13485 (2020) | UN38.3, UL, CE, GB ([qualification](https://www.grepow.com/qualification.html)) | — | DigiKey lists Grepow Inc cells, e.g. [GRP652348 850 mAh](https://azcus.digikey.com/en/products/detail/grepow-inc/GRP652348-1C-3-8V-850mAh/25603169); own US shop [genstattu.com](https://genstattu.com/c220-4812050.html) | "29+ years" and "more than 26 years" on the same page |
| EEMB ([eemb.com](https://www.eemb.com/information/18)) | Since 1995 ([LinkedIn](https://www.linkedin.com/company/eemb-battery)) | ISO 9001, ISO 14001, TS16949; ITAR-registered ([eemb.com](https://www.eemb.com/categories-62)) | UL1642, IEC/EN 62133, UN38.3, KC, PSE, CE | — | Official AliExpress store ([LP903436 1050 mAh, US$ 13.99](https://www.aliexpress.com/i/1005004971746148.html)); Amazon brand store | No fitting standard size |
| PKCell, Shenzhen ([pkcell.com](https://www.pkcell.com/about/)) | "1998" on its site, "2006" on [LinkedIn](https://www.linkedin.com/company/shenzhen-pkcell-battery-co-ltd) | ISO 9001 ([press release](https://www.registerguard.com/press-release/story/17696/global-leading-li-polymer-battery-pack-factory-pkcell-battery/)) | — | — | DigiKey stocks [LP503035](https://www.digikey.com/en/products/detail/pkcell/LP503035/26740792); Adafruit cell datasheets name Shenzhen PKCell ([example](https://cdn-shop.adafruit.com/product-files/1578/Datasheet.pdf)) | Two sites: pkcell.com lists no cell between LP552535 and LP503562 ([catalogue](https://www.pkcell.com/product-category/lithium-polymer-battery/)), while [batterypkcell.com](https://www.batterypkcell.com/lp803035-lithium-polymer-battery-product/) lists an LP803035 800 mAh from a Longhua office address. The LP503035 page says 500 mAh in the title and 350 mAh in the text ([pkcell.com](https://www.pkcell.com/product/lp503035-500mah-3-7v/)) |
| LiPol Battery Co., Shenzhen ([lipobatteries.net](https://www.lipobatteries.net/about-us/)) | "Over 30 years"; elsewhere "founded in 1995" ([lipolbatteries.com](https://www.lipolbatteries.com/about)) and "found in 2002" ([lipolbattery.com](https://www.lipolbattery.com/)) | ISO 9001 claimed | UN38.3, MSDS; "CB, IEC62133-2017" on LP103035, no lab or number | — | Many sister domains (li-polymer-battery.com, lipo-battery.com, lipobattery.us) | Same model with 2–5 different capacities across its own tables; LP803035 sold as 1000 mAh while its table says 800/820 mAh ([LP803035](https://www.lipobatteries.net/hot-selling-lipo-battery/un38-3-msds-lp803035-1000mah-3-7v-li-po-batteries/)) |
| Guangdong Ufine New Energy / BENZO Energy ([ufinebattery.com](https://www.ufinebattery.com/about/certification/), [bzbattery.com](https://www.bzbattery.com/about-benzo-lithium-battery.html)) | Team from 2008, "Ufine" brand 2015 ([Made-in-China profile](https://ufinebattery.en.made-in-china.com/company-Guangdong-Ufine-New-Energy-Co-Ltd.html)); cell factory in Jiangmen, pack factory in Dongguan, sales office in Shenzhen | ISO 9001, ISO 45001 (images); ISO 14001 per a [factory-visit post](https://www.facebook.com/groups/2701829233477561/posts/4587449941582138/) | KC, UL1642, UL2054, IEC 62133, CB, PSE, UN38.3, CE, RoHS (labels only, no numbers) | Made-in-China: other listings of the same seller carry the "Audited Supplier" badge, the 103030 listing does not ([listing](https://www.made-in-china.com/price/prodetail_Lithium-Battery_iphRnXlCbscf.html)) | — | One company, many names and domains (benzoenergy.com, bzbattery.com, bz-battery.com, ufinekorea.com, batterymanufactory.com …); BENZO prices "per Ampere" |
| Shenzhen Data Power (DTP) ([dtpbattery.com](https://www.dtpbattery.com/about/company-profile)) | Trading firm 2009, renamed 2011; Dongguan factory since 2016, over 10,000 m² | ISO 9001, ISO 14001, ISO 45001 | KC, UL, PSE, CE, CB, BIS, UN38.3, IEC 62133 (image list, [certificate page](https://www.dtpbattery.com/about/certificate)) | **Audited by BV**, report ID MIC-ASR242867 ([listing](https://dtpbattery.en.made-in-china.com/product/bOGJsaSlgUcn/China-1000mAh-3-7V-103035-Super-Thin-Li-ion-Square-Lipo-Battery-for-Baby-Monitor.html)) | SparkFun hosts a DTP datasheet ([DTP301120](https://cdn.sparkfun.com/assets/4/f/c/6/3/SPE-DTP301120SH-3.7V-40mah-En-1.0V.pdf)) | Factory size and staff differ between pages (10,000 m², 50,000 sq ft, 500 or 1,100 staff); 103035 listing says "weight 120g" |
| Yichun Topwell Power ([topwellpower.com](https://www.topwellpower.com/products/iec62133-un383-certified-603040-37v-750mah-lipo-batterty)) | 2002, Jiangxi | ISO 9001, ISO 14001, BSCI; SGS and Intertek audits | CE, CB, IEC 62133, UL, PSE, UN38.3 | — | — | No fitting model; a blog post gives an 850 mAh polymer cell 11 g ([topwellpower](https://cn.topwellpower.com/info-detail/key-specifications-of-the-37v-850mah-battery-for-iot-device-manufacturers)), about 286 Wh/kg (est.) |
| Shenzhen Bihuade / "Liter Energy" ([bihuade.com](https://bihuade.com/pages/about-us), [battery-lipo.com](https://www.battery-lipo.com/index.php?c=category&id=14)) | "Built in 2007, 7,000 m², TÜV certified factory"; also "founded in 2002" ([akkus-battery.com](https://www.akkus-battery.com/)), "established in 2013" ([liter-energy-battery.com](http://www.liter-energy-battery.com/)) and "over 30 years" | — | IEC 62133-2:2017 page ([liter-energy-battery.com](http://www.liter-energy-battery.com/index.php?s=sycp&c=show&id=19)) | — | Retail Shopify shop and Amazon brand "Liter" | Four founding stories; bihuade.com says it works with a "partner of manufacturing" |
| Guangzhou Great Power (300438.SZ) ([greatpower.net](https://www.greatpower.net/)) | 2001, listed company | — | — | — | Some GSP-series cells at distributors, e.g. [GSP503450](https://www.ozdisan.com/en/p/sarj-edilebilir-lityum-piller-738/great-power-gsp503450-531950) | Now energy-storage focused; its consumer brochure covers e-cigarette cells ([PDF](https://www.greatpower.net/vancheerfile/files/2023/11/20231127113929354.pdf)). Unrelated firms trade on the name ([greatpow.com](https://greatpow.com/), [greatpower-battery.com](https://greatpower-battery.com/)) |
| Guangzhou Fullriver | "FULLRIVER" brand now owned by Guangzhou Battsys ([Made-in-China](https://www.made-in-china.com/showroom/925208/)) | — | — | — | [fullriverbattery.com](https://fullriverbattery.com/) sells AGM lead-acid | No small LiPo pouch catalogue found |
| Shenzhen Hondark Electronics | Cell maker behind TinyCircuits' LiPos ([ASR00012 datasheet at Mouser](https://www.mouser.com/datasheet/2/855/ASR00012_1000mAh-3078650.pdf)) | — | UL1642 certificate for TinyCircuits cells lists Shenzhen Hongshengze Energy Technology as holder ([PDF](https://files.tinycircuits.com/Datasheets/ASR00036_850mAh_UL1642.pdf)); IEC 62133-2 report TCT191210B005 for model 552325 ([Scribd](https://www.scribd.com/document/955677255/ASR00007-290mAh-IEC62133)) | — | Mouser via TinyCircuits | No public catalogue, prices or own site found; [Made-in-China showroom](https://www.made-in-china.com/showroom/truesupplier15/) only |
| Shenzhen WLY Electronics ("Wiliyoung") (Alibaba wlyoung / wiliyoung) | Founded 2016; 8,000 m²; 139 staff | — | Listing shows "TUV mark", "EN 62133", CE ([103030 listing](https://www.alibaba.com/product-detail/OEM-ODM-900mah-Lithium-Polymer-Battery-1600689544384.html)); a generic listing claims UL1642, IEC 62133, UN38.3, KC, BIS ([listing](https://www.alibaba.com/product-detail/WLY-lipo-battery-3-7v-rechargeable_1600837014983.html)) | **Verified by SGS**; US$ 90,000+ online revenue; replies ≤ 2 h | Indian retailer Robu.in stocks WLY cells ([WLY102050](https://robu.in/product/wly102050-1000mah-3-7v-single-cell-rechargeable-lipo-battery)) | Generic listing "Supply Ability 10000000 pieces per Month"; company profile behind a CAPTCHA (skipped) |
| Huizhou Jiaxinrui New Energy ("JXR") ([storefront](https://jiaxinrui.en.alibaba.com/productlist.html)) | Founded 2019; 6 years on Alibaba; "Custom Manufacturer" | — | CE, PSE, KC on listings | **Verified Pro**; US$ 180,000+ online revenue ([listing](https://www.alibaba.com/product-detail/_1600305140264.html)) | — | ICR18650 2600 mAh at US$ 0.72, labelled "Solid state" with model JXR403048 and "for Electric Vehicles"; 503040 "Solid State Battery … for Electric Vehicles"; 102535 sold as 1000 mAh. Own site jiaxinrui.cn did not resolve |
| Dongguan Mozhong Technology ("LUNKE") ([listing](https://www.alibaba.com/product-detail/103030-3-7V-1000mAh-High-Capacity_1601668524434.html)) | Founded 2024; 2 years on Alibaba; **"Collaborating factories 21"** | — | Listing: "UL/KC/CE/UN38.3/MSDS"; CE and RoHS declarations of conformity on the platform | Verified by SGS; store rating 4.7/5 (58); 93 % on-time; 21 % reorder; US$ 100,000+ | — | Same 103030 listed as "Semi-solid state" with NCM in one listing and "Liquid" with LiCoO2 in the other; applications "Electric Bicycles, Solar Energy Storage"; 1000 mAh at 13–15 g; sells "Samsungs" and "EVES" 21700 cells at US$ 0.75 |

**Other listings seen while searching, as warnings:**
- A "103030 3.7v 900mah" pouch listed with "Battery Size 18650", "Model Number 18650" and applications from golf carts to submarines. The seller has 245 m² of floor space and one QA inspector — [Shenzhen UNIS listing](https://www.alibaba.com/product-detail/OEM-103030-3-7v-900mah-Lithium_1600996466195.html).
- DNK Power's 903035 "1000 mAh" datasheet shows a 400 mA discharge curve lasting 300 minutes, which is 2000 mAh. The curve was copied from another cell — [datasheet](https://www.fpbattery.com/wp-content/uploads/2024/06/fpbattery-903035-3.7V-1000mAh-Lithium-Polymer-Battery-Specification.pdf).

**EU Battery Regulation readiness:**
- The only maker statement found is Grepow's: a 2024 press release says its metal-cased shaped cells are designed for the 2023/1542 removability rules. It is not a declaration of conformity — [Grepow news](https://grepow.com/company-news/metal-cased-shaped-lipo-batteries-for-advanced-wearables-is-unveiled.html).
- EEMB lists the old "Battery directive 2006/66/EC" — [eemb.com](https://www.eemb.com/information/18).
- One Alibaba trader displays an "(EU) 2023/1542" badge — [UNIS listing](https://www.alibaba.com/product-detail/OEM-103030-3-7v-900mah-Lithium_1600996466195.html).
- No maker names an EU authorised representative or publishes a carbon-footprint statement for portable cells. Carbon footprint is not required for portable batteries anyway.

### Inferences
- **Ufine/BENZO** is the best-documented maker that actually lists a fitting cell. It has its own cell plant and gives full PCM thresholds and a minimum capacity.
- **DTP** has the strongest third-party evidence among the mid-size makers (a BV audit with a public ID). Its 103030 would be a quote item, because only a 37 mm 103035 is listed.
- **WLY** is the credible one of the three shortlisted Alibaba sellers. Mozhong's 1000 mAh claim, its 2024 founding and its 21 "collaborating factories" point to a trader reselling unknown cells.
- **Grepow and EEMB** are the safe choices for a 1000-piece custom run, if the price and MOQ suit.

### Gaps
- Alibaba company-profile pages for WLY and Mozhong returned a CAPTCHA and were skipped. Floor space, staff and "Verified" status were read from the product pages' supplier cards.
- No public price was found for Grepow, EEMB, PKCell, Topwell, Hondark or Great Power for this size.

---

## Q3. Candidate cells

### Takeaway
At list price a fitting cell costs US$ 1.20–1.60 (CHF 0.99–1.32) at 10–1000 pieces from WLY, Ufine/BENZO, DTP or Mozhong. Retail shops with leads fitted cost US$ 3–6 per cell (Bihuade, LiPol's free-shipping shop). None of these listings states whether the price includes PCM plus JST PH, and none fixes the pin order. Write "PCM, JST PH 2.0 housing PHR-2, pin 1 = black = −, pin 2 = red = +, 50 mm lead" into the order. JST PH polarity is not standardised among sellers — [Particle forum](https://community.particle.io/t/why-isnt-battery-polarity-always-the-same-in-jst-pins/44474).

### Cited findings

| Cell | Maker | Size, nominal (max) mm | Capacity | PCM | Connector options | Max discharge | NTC | USD at 10 / 100 / 1000 (CHF) | MOQ | Sample | Lead time |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 103030 | WLY / Wiliyoung | 10 × 30 × 30 | 900 mAh, 3.33 Wh, 18 g | Yes (over-charge, over-discharge, short, temp.) | "SM, JST, JR …" and custom connectors from 500 pcs | 1C (900 mA) | not listed | 1.30 / 1.30 / 1.20 (1.07 / 1.07 / 0.99) | 10 | US$ 1.60 | 7 d (1–100), 12 d (101–5,000) |
| Ufx103030 | Ufine | 10 × 30 × 30 (no max given) | 850 mAh | not stated on listing | custom | not stated (1C on Ufine sister models) | "No" on Ufine sister models | 1.60 / 1.60 / 1.60 (1.32) | 6 | US$ 2.15 | contact |
| UFX 903030 | BENZO (Ufine) | 9 × 30 × 32 max | 800 mAh min, 820 typ, 17 g | not stated | not stated | 1C | not stated | 1.20 shown, "FOB 1.2–1.5 per Ampere", MOQ "1000 Ampere" (0.99) | unclear | — | — |
| DTP103035 (DTP103030 to quote) | Data Power | 10 × 30 × 35 (10.2 × 30.5 × 37) | 1000 mAh | not stated | "JST 2P / Molex" | 0.2–1C | — | 1.60 / 1.60 / 1.40 (1.32 / 1.32 / 1.15) | "1000PCS" vs. price tier from 2 | "Order sample" | 10 d |
| LP962830 | LiPol | 9.6 × 28 × 30 | 850 mAh | PCM standard on LiPol cells | JST, Molex, Hirose on request | — | 10 kΩ on request | no price; MOQ 5 for samples | 5 | yes | 3–7 d stock |
| 103030 "LUNKE" | Mozhong | 10 × 30 × 30 | "1000 mAh" (13–15 g) | variants "cell", "with PCM and cables", "with JST plug" | JST variant | not stated (charge 0.5C standard, 1C fast) | — | 1.40 / 1.35 / 1.30 (1.15 / 1.11 / 1.07); 2nd listing 1.20 at 1,000 | 1 | yes | 5 d (1–1,000) |
| 103030 | SCE | 10 × 30 × 30 | 900 mAh, 18 g, NCM | built-in PCM | — | — | — | — / 1.22 (50–499) / 1.16 (500+) | 50 | — | 7–10 d |
| 903030 "Liter" | Bihuade (retail shop) | about 30 × 30 × 9 | 800 mAh | "built-in protection PCB" | **JST PH 2.0 2-pin, or 3-pin with NTC**, PH 1.25, SH 1.0 | not stated | 3-pin option | 4.89 / 3.89 / 3.09 (4.03 / 3.21 / 2.55) | 1 | — | — |

Sources by row: [WLY](https://www.alibaba.com/product-detail/OEM-ODM-900mah-Lithium-Polymer-Battery-1600689544384.html) and [WLY connectors](https://www.alibaba.com/product-detail/WLY-lipo-battery-3-7v-rechargeable_1600837014983.html); [Ufine](https://www.made-in-china.com/price/prodetail_Lithium-Battery_iphRnXlCbscf.html); [BENZO](https://www.bzbattery.com/high-power-rechargeable-lipo-battery-for-prenatal-education-instrument-ufx-903030-800mah-3-7v-li-polymer-battery.html); [DTP](https://dtpbattery.en.made-in-china.com/product/bOGJsaSlgUcn/China-1000mAh-3-7V-103035-Super-Thin-Li-ion-Square-Lipo-Battery-for-Baby-Monitor.html); [LiPol table](https://www.lipobatteries.net/lipo-batteries-800mah/) and [LiPol options](https://li-polymer-battery.com/3-7v-rechargeable-li-polymer-battery-lp103035-1000mah-with-pcm-and-wires/); [Mozhong A](https://www.alibaba.com/product-detail/103030-3-7V-1000mAh-High-Capacity_1601668524434.html) and [Mozhong B](https://www.alibaba.com/product-detail/103030-3-7V-1000mAh-Rechargeable-LiPo_10000030919461.html); [SCE](https://www.alibaba.com/product-detail/103030-3-7V-900mAh-Lithium-Ion_1601590784925.html); [Bihuade](https://bihuade.com/products/903030-37v-800mah-liter-energy-battery-rechargeable-li-polymer-batteries-for-digital-products-toys).

**Retail and "free shipping" lots:**
- LiPol's free-shipping shop sells lots, e.g. LP703035 900 mAh and LP503450 850 mAh at US$ 599 for 100 pcs, which is US$ 5.99 a cell with shipping. Default packs have a PCM and 50 mm wires; connectors or NTC cost extra and add time — [LiPol free-shipping shop](https://www.lipobatteries.net/rechargeable-lipo-batteries-with-free-shipping/).
- Grepow's own US shop sells small cells at US$ 5.99 each (220 mAh) and ships only from the USA by FedEx or UPS — [genstattu.com](https://genstattu.com/c220-4812050.html).

### Inferences
- **WLY 103030 (900 mAh)** is the cheapest fitting cell with an honest rating and SGS-verified seller data.
- **Ufine 103030 (850 mAh)** or **BENZO 903030 (800 mAh, 32 mm max)** is the better-documented factory option, at US$ 0.30–0.40 more per cell.
- **LiPol LP962830** is the only fitting cell that avoids the width overhang. LiPol's data errors make a sample and capacity test mandatory.
- **Bihuade's shop** is the fastest way to get 10 cells with a JST PH 2.0 (or PH with NTC) already fitted. Check the pin order.

### Gaps
- The listing price for the "with PCM + JST" variant is not shown separately on any listing.
- No listing gives Swiss shipping costs ("Unable to calculate shipping" on all Alibaba pages).

---

## Q4. Getting lithium cells from China to Switzerland

### Takeaway
Loose Li-ion cells (UN3480) are fully regulated dangerous goods by air. IATA PI 965 **Section II no longer exists**: since 2022 every UN3480 consignment is Section IA or IB. That means Cargo Aircraft Only, a Class 9 lithium label, a Shipper's Declaration, **at most 30 % state of charge**, and at most 10 kg net per package for IB. Only DG-approved accounts can ship this way. DHL China charges CNY 800 (about CHF 99) per shipment for full DG, so express costs are dominated by that fee for small orders: **est. US$ 150–250 for 10 cells, US$ 200–350 for 100, US$ 400–900 for 1000**. Most Chinese battery sellers therefore offer "special line" or "battery line" DDP services (consolidated air or truck plus local delivery). These cost about ½ to ¼ of express but take **20–35 days** and may come without customs papers. Switzerland charges no duty on HS 8507.60 since 2024. Import VAT is 8.1 % on goods plus freight, and is not collected below CHF 5 of tax (about CHF 62 of value). The courier's clearance fee is CHF 19–25. The **INOBAT advance disposal fee** is **CHF 0.05 per Li-ion cell of 1–24 g**, owed by whoever first places the cells on the Swiss market. Swiss Post cannot carry loose lithium cells.

### Cited findings

**IATA rules (2026):**
- PI 965 Section IA covers cells over 20 Wh. **Section IB covers cells of 20 Wh or less**, at most 10 kg net per package, Cargo Aircraft Only, in packaging that passes a 1.2 m drop and 3 m stack test. It needs the Class 9 lithium battery label, the battery mark, the CAO label and a Shipper's Declaration, plus DG training. **All UN3480 must be shipped at 30 % SoC or less**; more needs state approval (A331) — [IATA Lithium Battery Guidance 2026](https://www.iata.org/contentassets/05e6d8742b0047259bf3a700bc9d42b9/lithium-battery-guidance-document.pdf).
- Section II of PI 965 was removed in the 2022 DGR — [J.J. Keller](https://jjkellercompliancenetwork.com/news/iata-releases-its-list-of-changes-for-2022-dgr-2657398191). The 30 % rule has applied since 1 April 2016 — [Air Cargo News](https://www.aircargonews.net/?p=13498).
- Since 1 January 2026, cells **packed with** equipment (UN3481, PI 966) must also be at 30 % SoC or less. For cells **contained in** equipment (PI 967) it is "strongly recommended" — [IATA guidance](https://www.iata.org/contentassets/05e6d8742b0047259bf3a700bc9d42b9/lithium-battery-guidance-document.pdf), pp. 13–14.
- The UN38.3 test summary must be **made available** by manufacturers and distributors (since 1 January 2020); a URL or QR code is enough, and IATA does not require it with every shipment — [IATA guidance](https://www.iata.org/contentassets/05e6d8742b0047259bf3a700bc9d42b9/lithium-battery-guidance-document.pdf), [ICAO DGP WG](https://www2023.icao.int/safety/DangerousGoods/WG18/DGPWG.18.IP.004.3.en.pdf). The DGR does not require an SDS, but Chinese forwarders ask for the UN38.3 report, MSDS and drop-test report — [Grepow blog](https://www.grepow.com/blog/can-lipo-battery-cells-be-shipped-by-air.html).

**Couriers:**
- DHL Express accepts PI 965 IB only on approved accounts ("TDI – Account must be approved", service code HE, 10 kg per package, CAO) — [DHL Lithium Battery Guide v2.1, 2026](https://mydhlplus.dhl.com/content/dam/downloads/global/en/lithium-batteries/dhl_express_lithium_battery_guide.pdf.coredownload.pdf). DHL Switzerland states the same — [DHL CH](https://mydhl.express.dhl/ch/de/help-and-support/shipping-advice/what-can-i-ship/lithium-batteries.html).
- DHL "Full Dangerous Goods" surcharge from 1 January 2026: **CNY 800 per shipment** on the China rate card — [DHL CN surcharges](https://mydhlplus.dhl.com/cn/en/ship/surcharges.html). The Swiss rate card's CHF 95 applies to exports from CH — [DHL CH surcharges](https://mydhl.express.dhl/ch/en/ship/surcharges.html).
- FedEx: UN3480 is CAO with a Shipper's Declaration. From China it goes on International Priority or International Express Freight — [FedEx guide](https://www.fedex.com/en-ph/shipping-guide/pack/lithium-batteries/ion-cells/standalone/power-rating-less-than-equal-to-20wh/qty-less-than-equal-to-10kg.html). This was read only as a search excerpt; FedEx blocked fetching.
- UPS: UN3480 by air must be fully regulated — [UPS battery guide](https://www.ups.com/assets/resources/media/en_GB/pack_ship_batteries.pdf).

**What the suppliers say about shipping:**
- DNK Power: express adds "about 150-250 USD per shipment" in DG costs. Its "ALD" service (air plus FedEx/UPS ground, consolidated customs) takes "20-25 days to Europe (door to door)" at "1/2 or even 1/4" of the express cost, comes with no customs papers, and is occasionally delayed by up to 3 months. Express takes "5-10 days" — [DNK Power](https://www.dnkpower.com/how-to-ship-batteries/).
- LiPol ships by DHL, UPS and FedEx — [LiPol about](https://www.lipobatteries.net/about-us/).
- Topwell ships by sea, air and express from Shenzhen, Shanghai or Hong Kong and provides UN38.3 and MSDS — [Topwell](https://www.topwellpower.com/products/iec62133-un383-certified-603040-37v-750mah-lipo-batterty).
- SCE lists "UPS, DHL, Fedex or By Sea" — [SCE listing](https://www.alibaba.com/product-detail/103030-3-7V-900mAh-Lithium-Ion_1601590784925.html).
- Express costs about US$ 10–20 per kg plus DG fees and takes 3–7 days — [Lesso Solar](https://www.lessosolar.com/news/all-you-need-to-know-how-to-safely-ship-lithium-batteries-and-solar-energy-storage-from-china/). DG truck China–Germany takes 28–32 days — [Hartmann International](https://www.hartmann-international.de/en/air-sea-rail-2/china-direct-truck/).

**Swiss import:**
- Import VAT 8.1 %. Tax amounts of CHF 5 or less are not collected — [BAZG](https://www.bazg.admin.ch/de/postversand-interneteinkauf-kurierverkehr-einfuhr-firmen).
- No customs duty on industrial goods (chapters 25–97) since 1 January 2024 — [SECO](https://www.seco.admin.ch/de/aufhebung-industriezoelle).
- Clearance fees: DHL CHF 19 per shipment with an account, otherwise CHF 3 or 2 % of the duties and taxes — [DHL CH customs services](https://mydhl.express.dhl/ch/de/ship/customs-services.html). FedEx charges 2.5 % of duty and tax, minimum CHF 25, from 20 July 2026 — [FedEx CH](https://www.fedex.com/en-ch/shipping/surcharge-updates.html). Swiss Post charges CHF 16 + 3 % of value — [post.ch](https://www.post.ch/en/receiving-mail/import-customs-clearance) — but international mail admits only batteries installed in equipment — [Post & Parcel](https://postandparcel.info/?p=47790).
- Under DAP the recipient pays VAT and fees; under DDP/DTP the shipper is billed — [DHL CH](https://mydhl.express.dhl/ch/de/ship/customs-services.html).
- **INOBAT VEG:** producers and importers who first place batteries on the Swiss market must self-declare in the AVEG portal (quarterly, half-yearly or yearly). INOBAT uses BAZG import data to find importers who do not declare, and adds fees — [INOBAT Hersteller/Importeure](https://www.inobat.ch/de/recyclingpartner/hersteller-importeure). The 2026 tariff for Li-ion batteries of 1–24 g, "lose oder eingebaut in Gerät", is **CHF 0.05 per piece** excluding VAT (article 62001) — [INOBAT tariff 2026](https://www.inobat.ch/jwa/vfs/web/inobat.ch/media/recyclingpartner/hersteller-importeure/gebuehren-beitraege/Geb%C3%BChrentarif%20alle%20Batterien_01%2001%202026_DE.pdf). "Inverkehrbringen" in the Chemicals Act means supply to third parties, or import for professional or commercial use — [ChemG Art. 4](https://www.fedlex.admin.ch/eli/cc/2004/724/de).
- **EU Battery Regulation** (for the Camp in Germany): "making available" means supply "in the course of a commercial activity, whether in return for payment or free of charge" — [Regulation 2023/1542, Art. 3](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32023R1542). The Blue Guide says "occasional supplies by charities or hobbyists should not be considered" commercial — [Blue Guide 2022](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:52022XC0629(04)). Key dates: conformity assessment and CE from 18 August 2024; labelling from 18 August 2026 or 18 months after the implementing act; QR code and removability (Art. 11) from 18 February 2027 — [consolidated text 2026-08-13](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02023R1542-20260813).

**Estimated shipping cost per order (est., from the figures above):**

| Order | Gross weight | Express DG (DHL/FedEx/UPS), DAP | Battery special line, DDP | Transit |
|---|---|---|---|---|
| 10 cells | about 0.3 kg | US$ 150–250 | US$ 40–80 | 5–10 d / 20–35 d |
| 100 cells | about 3 kg | US$ 200–350 | US$ 60–140 | 5–10 d / 20–35 d |
| 1000 cells | about 20–25 kg (2+ IB packages) | US$ 400–900 | US$ 200–400 | 5–10 d / 20–35 d |

### Inferences
- A DG express fee makes 10 cells cost CHF 15–25 each landed. For prototypes, a retail shop with an EU or Swiss warehouse, or a supplier's battery line, is far cheaper per cell.
- The 30 % SoC rule means air-shipped cells arrive at about 3.7–3.8 V. Cells shipped full, or a whole lot reading 4.1–4.2 V on arrival, suggest they did not travel as declared air DG.
- On DDP special lines the forwarder normally pays Swiss VAT and builds it into the price. The INOBAT fee is still the importer's duty. For a hobby group's own use it is arguably not owed; for badges handed to others in Switzerland it is CHF 50 per 1000 cells. Ask INOBAT.
- Handing 100–300 badges to Camp visitors once, at cost or free, probably falls under the hobbyist exception of the EU Blue Guide. That is not certain.

### Gaps
- No supplier publishes a Swiss price for its battery line; quotes are needed. UPS's Swiss clearance fee was not verified.

---

## Q5. LCSC and JLC

### Takeaway
LCSC sells **no LiPo cells**. Its rechargeable-battery category holds two lead-acid blocks with zero stock. JLCPCB has a small "soft pack battery" range, but those parts are for PCBA only and are never shipped loose. Its largest fitting cell is 500 mAh. JLC Global Sourcing treats batteries as special (inspection and 3C fees) and does not process consigned batteries. LCSC is therefore not a route for the badge cell. The Asian makers' own distributor channels do not help a Swiss buyer much either. DigiKey's Swiss and German sites show its LiPo cells as "no longer available" (ground shipping only). EEMB's official AliExpress store has no 30 × 30 cell; its LP903436 1050 mAh is about 36 mm long.

### Cited findings
- LCSC "Batteries Rechargeable (Secondary)" lists two MEAN WELL lead-acid items (FT12-40 C42077383, FT12-100 C41510688), stock 0 — [LCSC category 57](https://www.lcsc.com/category/57.html). "Battery Packs" has 0 results — [LCSC category 59](https://www.lcsc.com/category/59.html).
- LCSC has no battery shipping page. It names DHL, UPS, FedEx, SF, Belgium Post and 4PX as carriers — [LCSC shipping methods](https://www.lcsc.com/help-center/shipping-delivering/shipping-methods).
- JLCPCB "Soft pack battery": 16 parts, PCBA only. The largest near-fit is FLYOUNG FLY.602535.500 (C5154891), 500 mAh, 35 × 25 × 6 mm, US$ 1.2946 at 36+. KAMCY 803450 1500 mAh (C55805827) is too long — [JLCPCB soft pack batteries](https://jlcpcb.com/parts/2nd/Industrial_control_electrical/Soft_pack_battery_165). These parts "cannot be shipped separately" — [JLC part C5154891](https://jlcpcb.com/partdetail/FLYOUNG-FLY_602535500/C5154891).
- JLC Global Sourcing charges commodity-inspection and 3C fees (US$ 20 per part type) for batteries and never ships parts to the customer — [JLC help](https://jlcpcb.com/help/article/how-to-use-jlcpcb-global-sourcing-parts-service). Consigned batteries "will not be processed" — [JLC consignment terms](https://jlcpcb.com/help/article/consignment-part-terms-conditions).
- DigiKey: Jauch LP523450JU is active with 1,465 in stock on digikey.com ("Air shipments of this product are unavailable"), but digikey.ch shows it and other LiPos as "no longer available" — [DigiKey Jauch LP523450JU](https://www.digikey.com/en/products/detail/jauch-quartz/LP523450JU-PCM-2-WIRES-70MM/9560988). "DigiKey does not ship products containing lithium by air" — [DigiKey forum 2020](https://forum.digikey.com/t/lithium-battery-shipping/8153). PKCell's LP503035 with a PH plug is a DigiKey Marketplace item shipped by Fuspower/PKCell at US$ 7.95 for 1 — [DigiKey](https://www.digikey.com/en/products/detail/pkcell/LP503035-W-PLUG/26906441).
- EEMB Official Store on AliExpress: LP903436 1050 mAh at US$ 13.99 — [AliExpress](https://www.aliexpress.com/i/1005004971746148.html). An unbranded store sells a 103030 900 mAh with a PH 2.0 plug at US$ 8.45 — [AliExpress](https://www.aliexpress.com/i/3256812599596494.html). Shipping to CH was not checked; the pages were read with a US ship-to.
- For reference (covered in the European note): Conrad.ch sells the Akyga LP103035 (1050 mAh, 35 × 30 × 10 mm, PCM, JST SYP 2.54 mm lead) at CHF 13.95 from Swiss stock — [Conrad](https://www.conrad.ch/de/p/akyga-lp103035-akkupack-x-spezial-akku-lipo-3-7-v-1050-mah-3385847.html).

### Gaps
- Mouser blocked automated access; its LiPo range and CH shipping were not checked.

---

## Q6. Recommendation: best makers and landed cost per cell

### Takeaway
Order 10 samples each from **WLY (103030, 900 mAh)** and **Ufine/BENZO (903030 800 mAh or 103030 850 mAh)**, plus **LiPol LP962830** if the 0.5 mm overhang matters. Measure them, then order the production lot from the winner. Ask **DTP** for a quote on a 103030 with the same PCM and connector, as a BV-audited fallback. Use **Grepow** if a custom-size 1000-piece run with full documentation is wanted. Landed per cell (est.):

| Maker, cell | 10 cells: express DG / special line | 100 cells: express / special line | 1000 cells: express / special line |
|---|---|---|---|
| WLY 103030 900 mAh (US$ 1.30 / 1.30 / 1.20) | CHF 21.53 / 6.07 | CHF 3.96 / 2.10 | CHF 1.73 / 1.39 |
| BENZO UFX 903030 800 mAh (US$ 1.20) | CHF 21.44 / 5.99 | CHF 3.87 / 2.01 | CHF 1.73 / 1.39 |
| Ufine Ufx103030 850 mAh (US$ 1.60) | CHF 21.79 / 6.82 | CHF 4.22 / 2.37 | CHF 2.08 / 1.75 |
| DTP 103030 (quote; priced as DTP103035, US$ 1.60 / 1.60 / 1.40) | CHF 21.79 / 6.82 | CHF 4.22 / 2.37 | CHF 1.91 / 1.57 |
| for comparison: Mozhong "1000 mAh" (US$ 1.40 / 1.35 / 1.30) | CHF 21.62 / 6.15 | CHF 4.00 / 2.15 | CHF 1.82 / 1.48 |
| for comparison: LiPol shop lot, 100 pcs incl. shipping (US$ 599) | — | CHF 5.39 | — |

Assumptions (all est.):
- Unit prices as listed 2026-10-17 at 1 USD = 0.824 CHF.
- Freight:
  - Express DG: US$ 200, 280 and 650 for 10, 100 and 1000 cells.
  - Special line: US$ 60, 100 and 300.
- Swiss VAT 8.1 % on goods plus freight, skipped where the tax is CHF 5 or less (10 cells by special line).
- CHF 25 clearance fee on express only.
- INOBAT CHF 0.05 per cell plus VAT on every row.
- No PCM or connector surcharge and no bank fees. Add US$ 0.10–0.30 per cell if the PCM + JST PH variant is priced extra (est.).

### Cited findings
- Prices, MOQs and ratings: see Q3. Shipping and import figures: see Q4.
- The repo BOM's CHF 0.68–0.85 at 100+ is below every 103030 listing found here. The lowest fitting cells were US$ 1.16–1.20 (CHF 0.96–0.99) at 500–1000 pieces (SCE, WLY, Mozhong listing B). The CHF 0.68–0.85 figures match Jiaxinrui's US$ 0.66–0.85 listings for other sizes (102535, 602030) — [Jiaxinrui storefront](https://jiaxinrui.en.alibaba.com/productlist.html).

### Inferences
- At 1000 cells the cell is about CHF 1.0 and shipping, VAT and the INOBAT fee add CHF 0.4–0.8. At 10 cells shipping is everything.
- Getting samples by battery line costs about CHF 60 per supplier, against CHF 200+ by express. For the first 10 prototypes, a cell from Swiss stock costs less than any direct import: for example the Akyga LP103035 at CHF 13.95 from Conrad.ch, though it is 35 mm long and needs re-terminating (see Q5 and the European note).
- At 100 cells and up, a direct order by battery line (CHF 2.0–2.4 a cell) is clearly cheaper than retail.

---

## Q7. Documents to request before ordering

1. **Cell specification / datasheet** with the maker's name and model, a drawing with **maximum** T × W × L including PCM and lead exit, nominal and **minimum** capacity at 0.2C, internal resistance, max continuous and pulse discharge, and charge limits.
2. **PCM specification**: protection IC and MOSFET part numbers, over-charge detect and release, over-discharge detect and release, over-current and short-circuit trip with delays, standby current. Ufine-class values are 4.28 V / 2.4 V / 2.5–4.5 A ([Ufine](https://www.ufinebattery.com/products/3-7-v-800mah-lithium-ion-battery-803035/)).
3. **Connector drawing**: JST PH 2.0 (genuine JST PHR-2 or named clone), pin 1 = black = −, pin 2 = red = +, lead length, wire gauge. Optionally a third NTC wire (10 kΩ, B = 3435).
4. **UN38.3 test summary** for **this model and capacity**, naming the test lab, report number and date. The summary must list the manufacturer and the Wh rating; the model name must match the label.
5. **IEC 62133-2:2017 test report or CB certificate** from a recognised lab (TÜV, SGS, Intertek, UL, BV or another CB body), with the same model. Check CB certificates on the issuing body's online database.
6. **SDS (MSDS)** in English, current revision (GHS format).
7. **Air/sea transport condition appraisal** (the Chinese "运输条件鉴定书") and the forwarder's statement that cells ship at **≤ 30 % SoC** under PI 965 IB (or as sea or road DG).
8. **Drop-test report (1.2 m)** if the forwarder asks for it.
9. For the Camp in the EU: a **declaration on Regulation (EU) 2023/1542** (at least Annex I mercury, cadmium and lead limits) and the label text.
10. Commercial terms: Incoterm (DDP vs DAP), who pays Swiss VAT and clearance, delivery time, and whether the supplier's battery line delivers to Switzerland (many "EU" lines stop at the EU border).

---

## Q8. Incoming inspection checklist

Do this for every lot, on all cells for 10–100 pieces and on a sample (e.g. 32 of 1000 plus all visual checks) for 1000.

1. **Paperwork**: label model, capacity and Wh match the datasheet and the UN38.3 summary; date code within 3–6 months.
2. **Visual**: no dents, punctures, tab tears, leaking electrolyte smell, or loose Kapton over the PCM. Leads firm, with no exposed copper at the PCM.
3. **Dimensions** with calipers: thickness at the centre and at the PCM end, width, length including PCM. Reject anything over the drawing maximum. Check flat fit on the board (≤ 34 mm, width 30.0–30.5 mm).
4. **Swelling**: lay the cell on glass. It must not rock. Re-check thickness after the first full charge and after 1 week; growth over about 0.3 mm (est.) means reject the lot.
5. **Polarity**: multimeter on the JST plug before any connection, red probe on pin 2. Must read + 3.6 to 3.9 V. A reversed reading means re-pin or reject.
6. **Open-circuit voltage** on arrival: expect about 3.7–3.85 V (≤ 30 % SoC rule for air). Spread across the lot within 50 mV (est.). A cell under 3.0 V has been over-discharged: reject.
7. **Internal resistance** at 1 kHz (cheap IR meter): typical ≤ 115–180 mΩ for cell plus PCM per the datasheets above. Outliers above 1.5 × the median: reject.
8. **Capacity test** on a sample: charge CC/CV 0.5C to 4.2 V, cut off at C/20, rest 1 h, discharge at 0.2C to 3.0 V. Pass if ≥ the datasheet minimum (expect 800–900 mAh, not 1000). Also run one discharge at the badge's 0.8 A to confirm voltage stays above 3.4 V for most of the run.
9. **PCM trip tests** on a few cells:
   - Short circuit: short the leads for under 1 s through a 10 A fuse. The output must cut off within milliseconds and recover when a charger is connected.
   - Over-current: step a load from 2 A to 5 A. Note the trip current; it should be in the 2.5–5 A band.
   - Over-discharge: discharge at 0.2C past 3.0 V. The PCM should open at about 2.4–2.5 V.
   - Over-charge: with a lab supply limited to 100 mA, raise the voltage slowly. The PCM should open at about 4.25–4.30 V.
10. **Self-discharge**: after the capacity test, charge to 3.9 V, wait 7 days, re-measure. A drop over 30 mV (est.) flags a soft short.
11. **Badge test**: plug into one badge. Check charging (red LED, 400 mA), charge termination at 4.2 V, and Q103 reverse-polarity behaviour with a deliberately reversed lead.
12. Store the cells at 40–60 % charge in a metal box or LiPo bag, away from the soldering area. Keep the UN38.3 summary and SDS with the lot.
