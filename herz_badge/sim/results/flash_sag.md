# White flash on a low battery (sim/flash_sag.py)

| Cell | Charge | Open-circuit | VSW min | 3V3 min | Brownout? |
| --- | --- | --- | --- | --- | --- |
| 103030 1000 mAh | 50 % | 3.83 V | 3.33 V | 3.22 V | no |
| 103030 1000 mAh | 20 % | 3.72 V | 3.22 V | 3.11 V | no |
| 103030 1000 mAh | 10 % | 3.62 V | 3.12 V | 3.01 V | no |
| 103030 1000 mAh | 5 % | 3.50 V | 3.00 V | 2.88 V | no |
| 102030 600 mAh | 50 % | 3.83 V | 3.24 V | 3.13 V | no |
| 102030 600 mAh | 20 % | 3.72 V | 3.13 V | 3.02 V | no |
| 102030 600 mAh | 10 % | 3.62 V | 3.03 V | 2.91 V | no |
| 102030 600 mAh | 5 % | 3.50 V | 2.90 V | 2.79 V | **yes** |
| 25x30 350 mAh | 50 % | 3.83 V | 3.09 V | 2.97 V | no |
| 25x30 350 mAh | 20 % | 3.72 V | 2.98 V | 2.86 V | no |
| 25x30 350 mAh | 10 % | 3.62 V | 2.88 V | 2.76 V | **yes** |
| 25x30 350 mAh | 5 % | 3.50 V | 2.75 V | 2.63 V | **yes** |

Flash: 1175 mA of LEDs on top of the typical heart (139 mA) and the radio transmitting (192 mA). Brownout level 2.80 V.
