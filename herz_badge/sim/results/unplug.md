# USB unplug and replug (103030 1000 mAh, sim/unplug.py)

| Charge | VSYS on USB | VSYS on battery | VSW min | 3V3 min | Brownout? |
| --- | --- | --- | --- | --- | --- |
| 80 % | 4.58 V | 3.61 V | 3.59 V | 3.30 V | no |
| 30 % | 4.58 V | 3.37 V | 3.35 V | 3.30 V | no |
| 10 % | 4.58 V | 3.23 V | 3.21 V | 3.16 V | no |

Before the fix (R105 100k, no D104), 3V3 min: 80 %: 3.25 V, 30 %: 3.01 V, 10 %: 2.87 V (brownout below 2.80 V).
