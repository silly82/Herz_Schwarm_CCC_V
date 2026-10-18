# LiPo cells for the Herz badge from Swiss and European suppliers (state: October 2026)

Scope: who in Switzerland and the rest of Europe can sell us a protected single-cell LiPo that fits behind the 30 × 34 mm board (103030 first, then 103033/103035 up to 34 mm long, 902530/902535, 803030/803035), at 10, 100 and 1000 pieces, delivered to Switzerland, with documents we can trust. Asian factories are covered in `suppliers_asia.md`. Prices are "as listed 2026-10-18" (pages read on 18 October 2026) unless marked otherwise. A price taken from a search-engine snippet rather than from the page itself is marked "(snippet)". "Est." marks my own estimates and arithmetic.

Project facts used below (from `herz_badge/BOM.md` and `herz_badge/DESIGN.md` §3–4, not from the web): 3.7 V LiPo pouch charged to 4.2 V by a TP4056 at 400 mA. Load 130–230 mA typical, white-flash peaks about 1.2 A (firmware cap about 0.8 A), so ≥1C continuous discharge. Runtime target 5–8 h, so about 1000 mAh with 800 mAh as the floor. PCM required. JST PH 2.0 with pin 2 = + and pin 1 = GND, or bare leads. An NTC lead is welcome. Shortlist so far: 103030 "1000 mAh" from Alibaba at CHF 0.68–1.19.

From the Asia note (Q1), used here as given: reputable makers rate a 103030 at 800–900 mAh, not 1000 mAh. With its PCM a 103030 measures about 10.5 × 30.5 × 32–33 mm. The 35 mm sizes come to about 37 mm with the PCM.

Exchange rates: ECB reference rates of 2026-10-16, the last fixing before the reading date: 1 EUR = 0.9272 CHF, 1 EUR = 1.1253 USD, 1 EUR = 0.84385 GBP. So 1 USD = 0.8240 CHF and 1 GBP = 1.0988 CHF — [ECB daily XML](https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml).

---

## Q1. Catalogue distributors that serve Switzerland (Mouser, DigiKey, Farnell, RS, Distrelec, Conrad, TME, Reichelt)

### Takeaway
No catalogue distributor sells a ≥800 mAh LiPo that fits 30 × 34 mm to a Swiss address. **Mouser and DigiKey do not sell LiPo cells to Switzerland at all**: every LiPo pack on mouser.ch says "Mouser does not sell this product in your region", and digikey.ch hides them or calls them "no longer available". Farnell's Swiss catalogue has no LiPo pouch cells. RS, Distrelec and Reichelt do ship LiPo to Switzerland, but only larger packs (1.8–2 Ah, 35 × 67 mm) or small Renata cells (≤600 mAh). Two cells come close:
- **Jauch LP102530JU** fits (10 × 26 × 32 mm) and has a real datasheet with "UN 38.3 YES", but holds only **680 mAh**, below the 800 mAh floor. Conrad CH sells it through Galaxus at CHF 15.45.
- **Akyga LP103035** (Poland) holds **1050 mAh**, but its own datasheet allows **37.5 mm** assembled length, 3.5 mm more than the board, and shows no UN 38.3 summary. Conrad CH and TME list it.

Conrad.ch and TME could not be opened: both showed a Cloudflare bot check, so I used search snippets for them.

### Cited Findings

**Per distributor (seen 2026-10-18 from a Swiss session unless noted):**

| Distributor | What it shows for LiPo cells to CH | Fitting cell ≥800 mAh? | Evidence |
|---|---|---|---|
| Mouser (mouser.ch) | Battery Packs filtered to LiPo: 27 parts (Renata ICP, TinyCircuits, Mikroe, RRC, Soldered). Every one says "Mouser does not sell this product in your region" and "Shipping Restricted". The 3.7 V Li-ion packs are blocked the same way; one Adafruit pack says "Due to government regulations, Mouser is unable to sell this product in your country." | No. Closest: Renata ICP582930PR-01, 450 mAh, 32.0 × 29.5 × 6.2 mm (blocked); TinyCircuits ASR00012, 1 Ah, 30 × 40 × 8 mm (blocked) | [Mouser CH LiPo packs](https://www.mouser.ch/c/power/batteries/battery-packs/?battery%20chemistry=Lithium%20Ion%20Polymer%20(LiPo)); [ASR00012](https://www.mouser.ch/en/ProductDetail/TinyCircuits/ASR00012?qs=0lSvoLzn4L%2FDH7Pi1IBo3A%3D%3D); [Li-ion 3.7 V packs](https://www.mouser.ch/c/power/batteries/battery-packs/?battery%20chemistry=Lithium%20Ion%20(Li-Ion)&output%20voltage=3.7%20V) |
| DigiKey (digikey.ch) | The rechargeable-battery category shows 725 parts in CH; only 4 are "Lithium-Ion Polymer", none ≤34 mm. The Jauch LP102530JU page on digikey.ch says "This product is no longer available at DigiKey". The same part on digikey.com is in stock (278) with "This product contains Lithium. Air shipments of this product are unavailable at this time." A DigiKey forum post says lithium ships by FedEx/UPS Ground only. | No | [digikey.ch category](https://www.digikey.ch/en/products/filter/batteries-rechargeable-secondary/91); [digikey.ch LP102530JU](https://www.digikey.ch/en/products/detail/jauch-quartz/LP102530JU-PCM-2-WIRES-50MM/9560985); [digikey.com LP102530JU](https://www.digikey.com/en/products/detail/jauch-quartz/LP102530JU-PCM-2-WIRES-50MM/9560985); [DigiKey forum 2020](https://forum.digikey.com/t/lithium-battery-shipping/8153) |
| Farnell (ch.farnell.com) | The Swiss "Akkus" category has 63 products: lead-acid, Panasonic VL coin cells, FEY/Panasonic Li-ion device packs. No LiPo pouch cell. LP102530JU gives a 404 page and "keine Produkte gefunden". Battery rows say "Gefahrgut: … kann es bei diesem Artikel zu einer Verzögerung der Lieferzeit kommen". Farnell UK lists LP102530JU (52 in stock, £16.82 @10, £14.88 @50, snippet). | No | [Farnell CH Akkus](https://ch.farnell.com/c/batterien-akkus-ladegerate/akkus); [CH search](https://ch.farnell.com/search?st=LP102530JU); [Farnell UK LP102530JU](https://uk.farnell.com/jauch/lp102530ju/batt-rechargeable-li-ion-0-7ah/dp/4551040) |
| RS (ch.rs-online.com) | Ships LiPo to CH. Only two LiPo pouch packs: RS PRO 144-9405 (1.8 Ah, 35 × 67 × 10.4 mm, CHF 14.95, "Normen/Zulassungen: No") and RS PRO 125-1266 (2 Ah, CHF 23.96). "Akku Sondergrössen" holds 78 items; the rest are 18650/21700, NiMH and coin cells. | No | [RS 144-9405](https://ch.rs-online.com/web/p/akku-sondergroessen/1449405); [Akku Sondergrössen](https://ch.rs-online.com/web/c/batterien-und-ladegerate/akkus/akku-sondergroessen/) |
| Distrelec (distrelec.ch, RS group) | Ships from Nänikon, next working day in CH. Seven LiPo packs: six Renata ICP on clearance ("Aktion", −48 to −75 %, "Verfügbar, so lange der Vorrat reicht"), the largest ICP622540PMT 600 mAh (42.5 × 25.7 × 6.5 mm, CHF 12.73 / 11.38 / 9.47 at 1 / 3 / 10 excl. VAT, country of origin China); plus RS PRO 1.8 Ah and Mikroe 2 Ah. Product pages say "Das Produkt ist als Gefahrgut klassifiziert". | No | [search "Akkupack Li-Po 3.7V"](https://www.distrelec.ch/de/search?q=Akkupack+Li-Po+3.7V&useListView=true); [ICP622540PMT](https://www.distrelec.ch/de/akkupack-icp-li-po-7v-600mah-kabelfuehrung-renata-icp622540pmt/p/30158724) |
| Conrad (conrad.ch) | Cloudflare "Verify you are human" on every page; not opened. Conrad.ch lists Akyga LP103035 as item 3385847 ([conrad.ch/fr listing](https://www.conrad.ch/fr/p/akyga-lp103035-pack-de-piles-rechargeables-x-batterie-speciale-lipo-3-7-v-1050-mah-3385847.html), found by search); the Asia note read its price as CHF 13.95. Through Galaxus/Digitec (supplier "Conrad CH") it sells Jauch LP102530JU at CHF 15.45 (min. 2, ">10 pieces in stock"), Renata ICP682828HPMT at CHF 20.45 (min. 2) and Akyga LP103040/LP803040 (40 mm long) at CHF 14.45. Galaxus shows Akyga LP103035 as "Currently out of stock". | Jauch fits but is 680 mAh; Akyga is 1050 mAh but 37.5 mm | [Galaxus LP102530JU](https://www.galaxus.ch/en/s1/product/jauch-lp102530ju-1-pcs-device-specific-680-mah-batteries-13148863); [Digitec ICP682828HPMT](https://www.digitec.ch/en/s1/product/renata-icp682828hpmt-special-rechargeable-battery-prismatic-cable-lipo-37-v-560-mah-370-v-560-mah-rc-44815221); [Galaxus LP103035](https://www.galaxus.ch/en/s1/product/akyga-lp103035-akkupack-x-spezial-akku-lipo-37-v-1050-mah-1-pcs-1050-mah-batteries-54220460); [Galaxus LP103040](https://www.galaxus.ch/en/s5/product/akyga-lp103040-akkupack-x-spezial-akku-lipo-37-v-1200-mah-1200-mah-370-v-rc-batteries-54220462) |
| TME (tme.eu, Poland) | Cloudflare check in the browser, HTTP 403 to the fetcher; not opened. Snippets show Akyga AKY-LP103035 at 6.60 USD @1, 5.86 @5, 5.50 @32, 5.13 @96 (net), and Cellevia ACCU-LP103035/CL (1050 mAh), a brand TME imports. Lithium shipping rules to CH not verified. | Akyga / Cellevia LP103035 (37.5 mm max) | [TME AKY-LP103035](https://www.tme.eu/en/details/aky-lp103035/rechargeable-batteries/akyga-battery/aky0662/) (snippet); [TME Akyga Li-Po overview](https://www.tme.eu/html/EN/akyga-battery-li-po-rechargeable-batteries/ramka_11095_EN_pelny.html); [TME Cellevia page](https://www.tme.com/us/en-us/manufacturers/p,cellevia-batteries_898/) (snippet); [Cellevia mirror at ormix.lv](https://ormix.lv/en/catalog/item/id/35362/) |
| Reichelt (reichelt.com/ch) | Ships to CH by DPD, EUR 10.25 up to 10 kg. Prices include 8.1 % Swiss VAT, and "Für Kunden in der Schweiz fallen keine zusätzlichen Verzollungskosten und Einfuhrumsatzsteuer an." The LiPo offer is RC packs (RD XT 800 S1, 53 × 30 mm) and device replacement cells. | No | [Reichelt search](https://www.reichelt.com/ch/de/shop/suche/lipo%20jst); [Reichelt Versandkosten](https://www.reichelt.com/ch/de/shop/service/-12_28) |

No Würth Elektronik LiPo cell was found; its Farnell brand page shows inductors, capacitors and battery-management transformers ([Farnell Würth page](https://de.farnell.com/b/wurth-elektronik)).

**Cells near the footprint that these channels carry:**

| Cell | Supplier(s) | Size T × W × L | Rated capacity | PCM | Leads / connector | Max continuous discharge | Charge temperature | NTC | Documents seen | Price, as listed 2026-10-18 | CHF | Stock | Fits 30 × 34 and ≥800 mAh? | Links |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Jauch LP102530JU** (Jauch no. 246510) | Galaxus/Conrad CH; DigiKey US; Farnell UK | 10.0 × 26.0 × 32.0 mm (Jauch list); 11 × 26 × 32 mm (DigiKey) | 700 mAh typ, 680 mAh min | yes (OCP 1.0–4.0 A, OV 4.28 V, UV 3.00 V) | 2 wires, 50 mm, bare | 1C = 700 mA | 0–15 °C at 0.2C, 15–45 °C at 1C, 45–50 °C at 0.5C and 4.1 V | no | Datasheet rev 1.2 (12/2024): "UN 38.3 YES", "IEC62133 NO", UL no. Jauch SDS for LPxxxxxxJU (2024) lists UN 3480, ADR SP188 and UN 38.3 | Galaxus CHF 15.45 incl. VAT, min. 2. DigiKey US $11.60 @1, $9.644 @10, $8.0225 @100, $6.925 @1024. Farnell UK £16.82 @10 (snippet) | Galaxus CHF 15.45; DigiKey CHF 7.95 / 6.61 / 5.71 at 10 / 100 / 1024 (US only) | Galaxus ">10"; DigiKey US 278 | Fits; **680 mAh, below floor** | [Galaxus](https://www.galaxus.ch/en/s1/product/jauch-lp102530ju-1-pcs-device-specific-680-mah-batteries-13148863); [datasheet](https://www.jauch.com/downloadfile/677e39d5dc1812655afe7605fec75d931/matd_246510_20200507_680mah_-_lp102530ju_1s1p_2_wire_50mm.pdf); [SDS](https://www.jauch.com/downloadfile/5c65204175cdd5d8024de2f8cf993a823/psds_jauch_lpxxxxxxju_2024.pdf) |
| **Akyga LP103035** (AKY0662) | Conrad CH, TME, Conrad.com, kamami.pl | cell 10.5 × 31.0 × 35.5 mm max; **assembled 10.5 × 31.0 × 37.5 mm max** | 1050 mAh at 0.2C | yes | 150 mm wires, JST SYP-02T-1 2.54 mm plug (not PH) | 1C = 1050 mA | 0–45 °C (standard charge 0–43 °C, quick charge 10–43 °C) | no | Spec approval sheet (2019); CE, RoHS, MSDS per Akyga page; no UN 38.3 or IEC 62133 shown | Conrad CH CHF 13.95 (from the Asia note; page not opened). TME 6.60 / 5.86 / 5.50 / 5.13 USD at 1 / 5 / 32 / 96 (snippet) | TME CHF 5.44 / 4.83 / 4.53 / 4.23 | Galaxus out of stock; others not verified | **No: 3.5 mm too long, 1 mm too wide** | [Akyga page](https://b2b.akyga.com/en/eacuxxxaky-08791-aky0662.html); [spec sheet](https://b2b.akyga.com/resources.php?code=en&src=%2Fapp_products_attachments%2Fproduct-cards%2Fsymbol%2FAKY0662%2Fcode%2Fen); [TME](https://www.tme.eu/en/details/aky-lp103035/rechargeable-batteries/akyga-battery/aky0662/) |
| Cellevia LP103035 (ACCU-LP103035/CL) | TME | same spec template as Akyga: 37.5 × 31.0 × 10.5 mm max assembled | 1050 mAh | not stated on listing | wires, JST SYR/SYP-02T socket | 1C | 0–45 °C | no | Spec approval sheet (2018) | EUR 9.00 @1, 8.20 @3 (ormix.lv mirror of TME data) | CHF 8.34 / 7.60 | 0 at the mirror | No: too long | [ormix.lv](https://ormix.lv/en/catalog/item/id/35362/); [spec sheet](https://ormix.lv/files/item_uploads/634f613513c6905ef514ceb2a15c88ea.pdf) |
| Renata ICP682828HPMT (part 101031) | Digitec/Galaxus via Conrad CH | 7.5 × 28 × 30 mm max (after 500 cycles) | 560 mAh typ, 530 mAh min | yes, "incl. NTC" | AWG 30 wires | 1C = 560 mA (2C pulse) | 0–45 °C; **charge to 4.35 V** | in the safety circuit | Datasheet V01 (11/2022) | CHF 20.45 incl. VAT, min. 2 | CHF 20.45 | ">10" | Fits; far too small | [Digitec](https://www.digitec.ch/en/s1/product/renata-icp682828hpmt-special-rechargeable-battery-prismatic-cable-lipo-37-v-560-mah-370-v-560-mah-rc-44815221); [Renata page](https://www.renata.com/en-us/products/lithium-polymer-batteries/icp682828hpmt/); [datasheet](https://www.renata.com/en-us/downloads/?product=icp682828hpmt&fileid=0d4019dcc8b5491495ba850d3e) |
| Renata ICP582930PR-01 | Mouser (blocked for CH) | 6.2 × 29.5 × 32.0 mm | 450 mAh | yes | wires | — | 0–45 °C (Mouser) | — | Renata transport info | not sold to CH | — | — | Fits; far too small | [Mouser listing](https://www.mouser.ch/en/ProductDetail/Renata/ICP582930PR-01?qs=WtvvTbtNXq%252BQsBQdyLLiKA%3D%3D) |

### Inferences
- Est.: scaling `DESIGN.md` §3 linearly, the Jauch cell's 680 mAh gives about 68 % of the 1000 mAh runtimes: about 5.1 h quiet, 2.8 h typical crowd, 4.1 h typical with the brightness cap. That is about 80 % of what a real 850 mAh 103030 would give.
- The Renata ICP682828HPMT is the only fitting cell with an NTC, but it is a 4.35 V cell. On the TP4056's 4.2 V it will not reach its rated 560 mAh.
- The Akyga and Cellevia LP103035 share one spec template, word for word, so they are very likely the same Chinese OEM cell under two brands.

### Gaps
- TME's price for Switzerland, its stock and its lithium shipping rules to CH could not be read (Cloudflare).
- Conrad.ch's own price, stock and shipping cost could not be read (Cloudflare).

---

## Q2. Maker shops in Switzerland and nearby

### Takeaway
No maker shop checked sells a ≥800 mAh cell that fits 30 × 34 mm. The hobby market carries PKCell/Adafruit/Pimoroni standard sizes: about 500 mAh in 30 × 35–37 mm, then 1000–1200 mAh in 34 × 50–62 mm. Swiss shops (bastelgarage.ch, pi-shop.ch, BerryBase CH, Galaxus/Digitec) show prices with Swiss VAT, deliver without a customs step, and bastelgarage states that the disposal fee is in the price. German shops ship LiPo to Switzerland only where the checkout offers it; Eckstein says some battery items ship "nur innerhalb Deutschlands". The maker channel is useful for chargers, JST PH leads and stand-in cells, not for the badge cell.

### Cited Findings

| Shop | LiPo cells listed (seen 2026-10-18) | Fits 30 × 34 and ≥800 mAh? | Price, shipping, disposal fee | Source |
|---|---|---|---|---|
| bastelgarage.ch (purecrea GmbH, Subingen) | Two pouch cells: 504050 1500 mAh JST 2.0 (CHF 10.90, out of stock) and 503290 2000 mAh JST 1.25 (CHF 13.90); otherwise 18650/21700 cells and M5Stack packs | No | Prices incl. 8.1 % VAT. "The advance disposal fee (ADF) is already included in the purchase price." | [search "lipo"](https://www.bastelgarage.ch/index.php?route=product/search&search=lipo); [1500 mAh cell](https://www.bastelgarage.ch/lipo-battery-1500mah-jst-2-0-lithium-ion-polymer); [return and disposal](https://www.bastelgarage.ch/batteries-rechargeable-batteries-return-disposal) |
| pi-shop.ch | Adafruit 150 mAh and 2000 mAh; "3.7 V 1000mAh" 4 × 50 × 50 mm; PIco LiPO 1000 mAh "5mm x 30mm x 50mm", 2C, PCB protection (CHF 7.90, out of stock); larger PIco/UPS packs | No | CHF prices incl. VAT | [search "polymer battery"](https://www.pi-shop.ch/catalogsearch/result/?q=polymer+battery); [PIco 1000 mAh](https://www.pi-shop.ch/pico-lipo-battery-1000mah) |
| play-zone.ch | Chargers and boards only; no LiPo cells under "lipo akku" or "mAh" | No | — | [search](https://www.play-zone.ch/de/catalogsearch/result/?q=lipo+akku&product_list_limit=100) |
| BerryBase CH / DE | PKCell LP-401230 … LP-785060 and Soldered cells with "2 Pin JST Stecker", e.g. LP-503035 500 mAh CHF 4.65, LP-503562 1200 mAh CHF 5.50 (most "aktuell nicht lieferbar"), Soldered 103048 1500 mAh CHF 8.15 | No (nearest LP-503035, 500 mAh) | CH: Swiss Post CHF 9.50, free from CHF 200; prices "inkl. MwSt." | [berrybase.ch search](https://www.berrybase.ch/search?search=lipo+akku); [berrybase.de search](https://www.berrybase.de/search?search=lipo+1000mah); [CH shipping](https://www.berrybase.ch/versand-und-zahlungsbedingungen/) |
| Eckstein (eckstein-shop.de) | PKCell LP401230 … LP785060 with "JST-PHR-2", e.g. LP503035 500 mAh, 35 × 30 × 5 mm, max discharge 0.5 A, EUR 5.19 incl. 19 % VAT | No | "Für Akkus, Batterien … gelten besondere Versandregeln. Einige Artikel können nur innerhalb Deutschlands oder nur mit bestimmten Versandarten versendet werden." Offers custom cells and packs via its PKNERGY page; no MOQ stated. | [LiPo category](https://eckstein-shop.de/Energie-Akkus-Batterien-LiPo-Akkus); [LP503035](https://eckstein-shop.de/LiPo-Akku-Lithium-Ion-Polymer-Batterie-37V-500mAh-mit-JST-PHR-2-Stecker-LP503035); [Versandinformationen](https://eckstein-shop.de/Versandinformationen); [Eckstein Akkus](https://eckstein-shop.de/Eckstein-Akkus) |
| EXP-Tech (exp-tech.de) | No generic LiPo cells; only BITalino 700 mAh and Crazyflie packs | No | — | [search "lipo"](https://exp-tech.de/search?q=lipo&type=product) |
| Pimoroni (UK) | LiPo Battery Pack 150 / 500 / 1200 / 2000 mAh; 500 mAh is 37 × 30.5 × 5.3 mm, 1200 mAh 64 × 35.5 × 5.3 mm; 100 mm JST lead, PCM, shipped 30 % charged | No | Ships to CH tracked, "duties calculated at checkout" (duties paid); no battery restriction stated on the shipping page | [product data](https://shop.pimoroni.com/en-ch/products/lipo-battery-pack); [shipping information](https://shop.pimoroni.com/en-ch/pages/shipping-information) |
| Galaxus / Digitec (marketplace; supplier "Conrad CH") | Jauch LP102530JU CHF 15.45; Renata ICP682828HPMT CHF 20.45; Akyga LP103040 and LP803040 CHF 14.45; Akyga LP103035 out of stock | Jauch and Renata fit but are 680 / 560 mAh | Minimum order 2; free shipping from CHF 50 | see Q1 links |
| accessoires-energie.com (French reseller) | Generic "103030" 1000 mAh, "About 10x30x30mm", EUR 14.99 incl. VAT; no maker, PCM, connector or documents named | Size yes; capacity claim doubtful (Asia note Q1) | No shipping-to-CH information | [product page](https://accessoires-energie.com/de/en-gb/products/batterie-li-po-3-7v-1000mah-103030) |

Polarity: the shops describe their leads only as "JST", "2 Pin JST Stecker" or "JST-PHR-2". None states which pin carries +, and none offers to re-pin a lead to our pin 2 = + (pin 1 = GND). Every lead has to be checked with a meter before it goes on a badge.

### Inferences
- In Europe the hobby LiPo range jumps from about 500 mAh in 30 × 35 mm to 1000 mAh and more in 34 × 50 mm. A 10 mm thick 30 × 30 mm cell is an industrial size that maker shops do not stock.
- For the 10 prototypes, a maker-shop cell can only be a stand-in, for example a 500 mAh LP503035 to test the charger and firmware.

---

## Q3. European cell makers and pack assemblers (Jauch, VARTA, Renata, RRC, Ansmann, Swiss assemblers)

### Takeaway
No European maker lists a standard ≥800 mAh cell in the 30 × 34 mm footprint. **Jauch** (Germany) comes closest with the 680 mAh LP102530JU and is the only one that says it builds "prototypes, samples and small series" in Germany, with its own UN 38.3 lab. **Renata** (Swiss, Swatch Group) tops out at 560 mAh in this footprint, and its cells are made in China. **VARTA**'s LPP packs are 34 × 50 mm and larger, and VARTA filed for insolvency in July 2026. RRC and Ansmann build large packs and say low volumes rarely justify a custom design. No Swiss assembler publicly offers small LiPo pouch packs. No European supplier publicly offers a JST PH lead with a chosen polarity at a stated minimum; that has to be quoted.

### Cited Findings

| Company | Country, type | Standard cells near our size | Custom / connector service | Stated minimum | Documents | Source |
|---|---|---|---|---|---|---|
| Jauch Quartz | DE, assembler (packs, own test lab) | LP102530JU 680 mAh (10 × 26 × 32); LP503030JU 450 mAh (5.2 × 30 × 30, PCM + NTC + Molex); nothing between 680 mAh and the 34.5 mm wide cells | "Standard cells and customized packs"; PCM on every pack; connectors "designed to your needs"; NTC on example packs; "Prototypes, samples and small series … are manufactured directly on our premises in Germany" | none stated | Own UN 38.3 testing and certificates; IEC 62133 and UL 2054 handled; SDS | [LiPo list](https://www.jauch.com/en-INT/products/battery_technology/getPrm/batteries/Lithium%20Polymer%20Batteries/); [battery development](https://www.jauch.com/en-FR/consulting/battery_development) |
| VARTA (VARTA AG / VARTA Storage) | DE, cell and pack maker | CellPac LITE 1/LPP 523450 S: 1000 mAh with NTC, 2 A, IEC 62133 (523450 = 5.2 × 34 × 50 mm by the usual naming); 1/LPP 503759 8HH 1400 mAh; older EasyPack types from 35.4 × 43.5 mm up to 36.6 × 64.5 mm | CellPac PLUS customised packs | none stated | UL 1642; IEC 62133 / UL 2054 on some models | [CellPac LITE](https://www.varta-ag.com/en/industry/product-solutions/power-pack-solutions/cellpac-lite); [1/LPP 523450 S](https://www.varta-ag.com/en/industry/product-solutions/power-pack-solutions/cellpac-lite/1/lpp523450-s); [EasyPack sizes](https://www.electronicdesign.com/power-sources/polymer-battery-suits-portable-electronics) |
| VARTA, company status | — | VARTA AG applied to open insolvency proceedings in July 2026; separate applications cover Varta Microbattery, Varta Micro Production and Varta Storage; "production is continuing" | — | — | — | [Euronews 2026-07-27](https://www.euronews.com/2026/07/27/varta-files-for-insolvency-as-german-battery-makers-crisis-deepens) |
| Renata SA | CH (Itingen), brand of Swatch Group; ICP cells "Herkunftsland China" per Distrelec | ICP682828HPMT 560 mAh (7.5 × 28 × 30, NTC, 4.35 V); ICP582930PR-01 450 mAh (6.2 × 29.5 × 32); ICP403029PL-02 325 mAh (4.4 × 31 × 31); range 35–2800 mAh | "individualized solutions and modifications for larger-volume projects" | "larger-volume", no number | "UN38.3 tested", "Many models already IEC62133 certified", "UL-listed battery cells" | [Renata LiPo range](https://www.renata.com/en-us/products/lithium-polymer-batteries/); [ICP682828HPMT datasheet](https://www.renata.com/en-us/downloads/?product=icp682828hpmt&fileid=0d4019dcc8b5491495ba850d3e); [Distrelec origin](https://www.distrelec.ch/de/akkupack-icp-li-po-7v-600mah-kabelfuehrung-renata-icp622540pmt/p/30158724) |
| Akyga (Ropla Elektronik, Suchy Dwór) | PL, brand / importer (cells from a Chinese OEM, see Q1) | LP103035 1050 mAh (37.5 mm); LP103040 1200 mAh; LP803040 1000 mAh; LP753636 1000 mAh (36 × 36); none in 30 × 34 | B2B portal; custom not stated | — | CE, RoHS, MSDS; 24-month warranty | [Akyga TME overview](https://www.tme.eu/html/EN/akyga-battery-li-po-rechargeable-batteries/ramka_11095_EN_pelny.html); [AKY0662](https://b2b.akyga.com/en/eacuxxxaky-08791-aky0662.html) |
| RRC power solutions | DE, pack maker | Smallest 1S packs are 2.35 Ah Li-ion and 3.81 Ah Li-polymer (RRC1120, RRC1130) | Custom packs | "There is no minimum order required" for standard packs | "worldwide national approvals" | [standard packs](https://www.rrc-ps.com/en/battery-packs/standard-battery-packs); [customer benefits](https://www.rrc-ps.com/en/battery-packs/standard-battery-packs/customer-benefits) |
| Ansmann | DE, pack assembler (DE and CN plants) | No standard single-cell LiPo | Custom Li-ion/NiMH packs; "low annual quantities" can make development not worthwhile | not stated | ISO 9001/14001/13485; test centre issues UN 38.3 and IEC 62133-2 certificates | [Ansmann battery packs](https://www.ansmann.de/en/solutions/battery-packs) |
| Akku Sys (Nord GmbH) | DE, assembler (B2B only) | NiMH, NiCd, primary lithium packs; no LiPo pouch named | "Von Einzelstück bis Serienfertigung" | from one piece | not stated | [Konfektionierung](https://akkusys.de/konfektionierung-akkupacks/) |
| pro-akkus GmbH | DE, assembler | Li-ion, LiFePO4, NiMH packs; LiPo pouch not named | "Klein- oder Großserie", prototypes | not stated | "UN-Test" mentioned | [Akkukonfektion](https://www.pro-akkus.de/akkupacks/akkukonfektion/) |
| Lithium System AG (Wetzikon) | CH, cell distributor and system integrator | EV-grade cells and modules; "auch unter 10'000 Stück" | Systems, certification | — | — | [lithiumsystem.ch](https://lithiumsystem.ch/) |
| Wyon AG | CH, medical micro-battery maker | Implantable cells 4.6–60 mAh; custom free-form cells | custom | "hängt vom jeweiligen Produkt ab" | IEC 62133, UN 38.3 | [wyon.ch products](https://wyon.ch/de/produkte) |
| akkushop-schweiz.ch | CH, retailer with "Akku-Konfektion" | NiMH/NiCd packs, one cylindrical 2S Li-ion pack; no LiPo pouch | solder tabs, Tamiya, MPX plugs | not stated | not stated | [Akku-Konfektion](https://www.akkushop-schweiz.ch/akkus/akku-nach-konfektion/) |
| Ineltro AG (Regensdorf) | CH, component distributor | No batteries shown on the Swiss page; offers cable assembly | — | — | — | [Ineltro AG](https://www.ineltro.eu/ineltro-ag-schweiz/) |

### Inferences
- Jauch is the one European source that could build a documented 103030-class pack with our JST PH polarity and an NTC, from prototypes upwards. Its price for 100 or 1000 is not public; DigiKey's US price for the LP102530JU ($8.02 @100, $6.93 @1024) is a rough ceiling for a standard Jauch cell.
- Renata and Akyga are brands over Chinese cells. Their value is European traceability (datasheet, SDS, an EU responsible entity), not a European cell.
- VARTA's insolvency makes it a poor choice for a new design in 2026, and its LPP sizes do not fit anyway.

### Gaps
- No public price or MOQ from Jauch, Renata or any assembler for a custom 103030 with a JST PH lead; quotes are needed.
- No Swiss pack assembler for small LiPo pouch packs was found by public search.

---

## Q4. Getting lithium cells to Switzerland: shipping rules, VAT and the disposal fee

### Takeaway
Buying from a Swiss shop or a Swiss storefront (Galaxus/Conrad CH, Distrelec, RS CH, bastelgarage, BerryBase CH, Reichelt CH) is simple: Swiss VAT of 8.1 % is in the price or added at checkout, there is no customs step, and the seller, not we, owes the CHF 0.05 disposal fee. Importing from an EU shop needs a courier: international mail carries no loose lithium cells. On the road, cells of ≤20 Wh (our 3.7–3.9 Wh cell) travel under ADR special provision 188 with light packing rules. The importer pays 8.1 % VAT on goods plus freight (waived if the tax is CHF 5 or less), the courier's clearance fee (CHF 16–25) and the CHF 0.05 INOBAT fee per cell.

### Cited Findings
- **Mail:** Swiss Post carries no dangerous goods in mail abroad; the exception is lithium batteries installed in devices, at most two batteries or four cells per parcel — [post.ch 2023](https://www.post.ch/de/ueber-uns/aktuell/2023/parfuem-und-handys-sind-gefahrgueter). The Asia note (Q4) cites the same rule for incoming international mail: only batteries installed in equipment — [Post & Parcel](https://postandparcel.info/?p=47790). Domestic parcels may carry lithium batteries up to 100 Wh — [post.ch Gefahrgut Inland](https://www.post.ch/de/pakete-versenden/gefahrgut/gefahrgut-inland).
- **Road transport (ADR SP188):** lithium-ion cells of ≤20 Wh and batteries of ≤100 Wh are exempt from most ADR provisions if they are protected against short circuit and packed in inner packagings inside strong outer packagings — [Gefahrgutshop SV 188 text](https://typo3.gefahrgutshop.de/fileadmin/pdfs/ADR_2023/Gefahrgutshop_Sondervorschrift_SV_188.pdf); [DBRS SP188 2025 summary](https://www.brs.dk/globalassets/brs---beredskabsstyrelsen/dokumenter/forebyggelse/2025/-sp188-2025-.pdf). Jauch's SDS lists UN 3480 and "ADR / RID 2023 SP188" for its LP cells — [Jauch SDS](https://www.jauch.com/downloadfile/5c65204175cdd5d8024de2f8cf993a823/psds_jauch_lpxxxxxxju_2024.pdf).
- **Shop rules seen:**
  - Mouser: not sold to CH (Q1).
  - DigiKey: not sold to CH; lithium by ground only (Q1).
  - Farnell CH: "Gefahrgut … Verzögerung der Lieferzeit" (Q1).
  - Distrelec: "als Gefahrgut klassifiziert"; ships from Nänikon (Q1).
  - Reichelt: DPD EUR 10.25 (CHF 9.50); VAT included, no extra clearance for Swiss customers (Q1).
  - BerryBase CH: Swiss Post CHF 9.50, free from CHF 200 (Q2).
  - Eckstein: some battery items "nur innerhalb Deutschlands" (Q2).
  - Pimoroni: ships duties-paid to CH; no battery rule stated (Q2).
  - Galaxus/Digitec: free shipping from CHF 50 (Q1).
  - TME: not verified.
- **Import VAT:** 8.1 % on goods plus freight; tax amounts of CHF 5 or less are not collected — [BAZG](https://www.bazg.admin.ch/de/postversand-interneteinkauf-kurierverkehr-einfuhr-firmen) (as cited in the Asia note Q4).
- **Clearance fees** (from the Asia note Q4): DHL CHF 19 per shipment with an account — [DHL CH](https://mydhl.express.dhl/ch/de/ship/customs-services.html); FedEx 2.5 % of duty and tax, minimum CHF 25 — [FedEx CH](https://www.fedex.com/en-ch/shipping/surcharge-updates.html); Swiss Post CHF 16 + 3 % of value — [post.ch](https://www.post.ch/en/receiving-mail/import-customs-clearance).
- **Disposal fee (VEG, INOBAT):** the 2026 tariff for "Lithium-Ionen-Akkumulatoren inkl. Akku-Packs" is CHF 0.05 excl. VAT per piece for 1–24 g (article 62001) and for 25–49 g (62002). Our cell weighs about 20 g — [INOBAT tariff 2026](https://www.inobat.ch/jwa/vfs/web/inobat.ch/media/recyclingpartner/hersteller-importeure/gebuehren-beitraege/Geb%C3%BChrentarif%20alle%20Batterien_01%2001%202026_DE.pdf). Producers and importers who first place batteries on the Swiss market declare and pay it — [INOBAT Hersteller/Importeure](https://www.inobat.ch/de/recyclingpartner/hersteller-importeure). Swiss shops include it in the shelf price; bastelgarage states this explicitly — [bastelgarage](https://www.bastelgarage.ch/batteries-rechargeable-batteries-return-disposal).

### Inferences
- From an EU shop, a 10-cell order pays roughly CHF 20–45 of freight and clearance (est.), which costs more than the cells. Swiss stock wins at 10 pieces.
- The CHF 0.05 fee is noise next to the cell price; what matters is who declares it. On a direct import it is ours.

---

## Q5. Ranking and landed cost per cell

### Takeaway
**There is no European source for a 30 × 30 mm cell of ≥800 mAh with a PCM and documents.** Every European option breaks one of our rules: either it fits and holds 680 mAh or less (Jauch, Renata), or it holds 1050 mAh and is 37.5 × 31 mm long (Akyga/Cellevia LP103035, 3.5 mm overhang). If the rules stay as they are, the production cell has to come from an Asian factory (Asia note: CHF 1.4–2.4 landed at 100–1000). The European channel is for **prototypes** and for **traceable documents**.

| Quantity | Best European option | Cell | Landed CHF per cell | Compared with Asia (Asia note Q6, est.) |
|---|---|---|---|---|
| 10 | Galaxus/Digitec (Conrad CH stock) | Jauch LP102530JU: fits, 680 mAh, UN 38.3 stated | **CHF 15.45** (shelf price; VAT and VEG included; free shipping from CHF 50) | CHF 5.99–6.82 by battery line, CHF 21.4–21.8 by express |
| 10, if 37.5 mm is acceptable | Conrad CH | Akyga LP103035: 1050 mAh, 3.5 mm overhang, no UN 38.3 shown | **CHF 13.95** (price from the Asia note; Conrad shipping not verified) | — |
| 100 | TME import (est.) | Akyga LP103035 | **CHF 5.12** (est.) | CHF 2.0–2.4 by battery line |
| 100, fitting cell | Jauch quote (est. at DigiKey's US price level) | LP102530JU or a custom Jauch 103030 | **CHF 7.70** (est.) | — |
| 1000 | TME import (est.) | Akyga LP103035 | **CHF 4.71** (est.) | CHF 1.4–1.8 by battery line |
| 1000, fitting cell | Jauch quote (est. at DigiKey's 1024-piece US price) | LP102530JU or a custom Jauch 103030 | **CHF 6.31** (est.) | — |

Assumptions (all est. except the shelf prices):
- Swiss shelf prices (Galaxus/Digitec, Conrad CH) include 8.1 % VAT and the CHF 0.05 VEG, as Swiss sellers do (Q4). Ten cells exceed the CHF 50 free-shipping line at Galaxus.
- TME: unit prices 5.86 USD at 10 and 5.13 USD at 100 and 1000 (snippet; no higher price break seen). Freight to CH est. EUR 20 / 25 / 60 for 10 / 100 / 1000 cells by courier. VAT 8.1 % on goods plus freight (CHF 5.41, 36.12, 346.89). Clearance CHF 25 per shipment. VEG CHF 0.05 plus VAT per cell. Arithmetic: 10 cells CHF 97.8 total; 100 cells CHF 512; 1000 cells CHF 4708.
- Jauch: no public price. I used DigiKey US prices ($8.0225 at 100, $6.925 at 1024) as a stand-in, plus EUR 25 / 60 freight from Germany, VAT, CHF 25 clearance and VEG. A direct Jauch quote may be lower or higher.
- No PCM, connector or NTC surcharge included. Re-terminating the Akyga JST SYP plug to JST PH is our own labour.

**Reputability:**
- **Jauch**: a German manufacturer of packs (not of cells). It publishes per-model datasheets with UN 38.3 status, an SDS with transport classes, and runs its own UN 38.3 lab. Best traceability in this note. Weak point: IEC 62133 "NO" on the LP102530JU.
- **Renata**: a Swiss brand with per-model datasheets, "UN38.3 tested", and NTC on the fitting model, but cells made in China and capacity far too low.
- **Akyga / Cellevia**: European brands (Ropla Elektronik, Poland; Cellevia via TME) over a generic Chinese spec sheet. They have an EU responsible entity and an MSDS, but no UN 38.3 summary or IEC 62133 report in public. Ask for both before buying 100+.
- **Mouser, DigiKey, Farnell**: would be the most traceable channel, but they do not sell LiPo to Switzerland.
- **Maker shops**: resellers of PKCell and similar cells; fine for stand-ins, not documented enough for 1000 badges.

### Inferences
- For the 10 prototypes, two orders from Swiss stock cover both questions: 10 × Jauch LP102530JU (mechanical fit, charger, firmware) for about CHF 155, and, if an overhang test is wanted, a few Akyga LP103035. Both arrive in days with no customs step.
- A 34 → 38 mm board or a battery bay that tolerates 37.5 × 31 mm would open the 1050 mAh LP103035 class from European stock at CHF 4.7–5.1 landed (est.).
- For 1000 badges the European premium over an Asian battery-line order is CHF 3–5 per cell, or CHF 3,000–5,000 in total (est.). It buys a European contact and paperwork, not a European cell.

### Gaps
- TME's Swiss shipping cost and lithium policy, and Conrad.ch's own price and shipping cost, were not readable (Cloudflare).
- No European quote for a custom 103030 with a JST PH lead (pin 2 = +) and an NTC; Jauch and Renata would need to be asked.
