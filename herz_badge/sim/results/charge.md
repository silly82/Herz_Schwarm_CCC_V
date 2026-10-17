# Charging (sim/charge.py)

| Cell | Current at 2 min | Charger heat, peak | CV reached | 80 % | Full (I < I_term) | SOC at end |
| --- | --- | --- | --- | --- | --- | --- |
| 103030 1000 mAh | 400 mA | 0.55 W | 2.3 h | 1.9 h | 2.6 h | 99 % |
| 102030 600 mAh | 400 mA | 0.54 W | 1.3 h | 1.1 h | 1.6 h | 99 % |
| 25x30 350 mAh | 400 mA | 0.52 W | 0.8 h | 0.7 h | 1.0 h | 99 % |

Thermal regulation holds the die at 120 degC: with theta_JA 70 degC/W at 25 degC ambient the charger may dissipate 1.36 W, so the current is limited to 1.36 W / (VBUS - VBAT) until the cell is above about 1.61 V.
