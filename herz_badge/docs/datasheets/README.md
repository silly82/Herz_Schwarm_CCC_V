# Datasheets

Status (2026-10-17): summaries for every active part on the badge and for the antenna candidates; the PDFs are
fetched by `scripts/fetch_datasheets.py` into this folder and not kept in git.

Each summary lists the numbers the design depends on with the datasheet page, and what they mean for this board.
DESIGN.md decisions D12–D16 come from them.

| Part | Summary | Used as |
| --- | --- | --- |
| ESP32-S3FH4R2 | [C3013940_ESP32-S3FH4R2.md](C3013940_ESP32-S3FH4R2.md) | U201 |
| WS2812B-2020-V6 | [C52917434_WS2812B-2020-V6.md](C52917434_WS2812B-2020-V6.md) | D301–D364 |
| TP4056 (UMW) | [C725790_TP4056.md](C725790_TP4056.md) | U101 |
| TP4054 (UMW) | [C668215_TP4054.md](C668215_TP4054.md) | replaced by the TP4056 (D14) |
| ME6217C33M5G | [C427602_ME6217C33M5G.md](C427602_ME6217C33M5G.md) | U102 |
| AO3401A | [C15127_AO3401A.md](C15127_AO3401A.md) | Q101, Q102, Q103 |
| SS14L | [C190475_SS14L.md](C190475_SS14L.md) | D101 |
| B5819WS | [C64886_B5819WS.md](C64886_B5819WS.md) | D104 (was D101) |
| SN74LVC1T45DBVR | [C7843_SN74LVC1T45DBVR.md](C7843_SN74LVC1T45DBVR.md) | U301 |
| QMI8658A | [C3021082_QMI8658A.md](C3021082_QMI8658A.md) | U202 |
| USBLC6-2SC6 (ST) | [C7519_USBLC6-2SC6.md](C7519_USBLC6-2SC6.md) | U103 |
| USBLC6-2SC6 (TECH PUBLIC) | [C2827654_USBLC6-2SC6.md](C2827654_USBLC6-2SC6.md) | not used: 5.0 V working voltage (D16) |
| JST S2B-PH-SM4-TB | [C295747_S2B-PH-SM4-TB-LF-SN-.md](C295747_S2B-PH-SM4-TB-LF-SN-.md) | J102 |
| MSK12C02 | [C431540_MSK12C02.md](C431540_MSK12C02.md) | SW101 |
| 40 MHz crystal (JGHC) | [C426988_S3240000101040.md](C426988_S3240000101040.md) | Y201 |
| 2.4 GHz chip antennas | [antennas.md](antennas.md) | AE201: Walsin RFANT3216120A5T (D15) |
