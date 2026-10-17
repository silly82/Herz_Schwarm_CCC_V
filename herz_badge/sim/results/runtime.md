# Runtime (sim/runtime.py)

| Cell | Scenario | Battery current | Runtime to VSW 3.4 V | SOC left | 3V3 then |
| --- | --- | --- | --- | --- | --- |
| 103030 1000 mAh | quiet (few badges, power 0.1) | 128 mA | 7.5 h | 4 % | 3.30 V |
| 103030 1000 mAh | typical crowd (power 0.5) | 233 mA | 4.1 h | 5 % | 3.30 V |
| 103030 1000 mAh | packed crowd (power 1.0) | 364 mA | 2.6 h | 6 % | 3.30 V |
| 103030 1000 mAh | typical, capped at 60 on battery | 160 mA | 6.0 h | 4 % | 3.30 V |
| 102030 600 mAh | quiet (few badges, power 0.1) | 128 mA | 4.5 h | 4 % | 3.30 V |
| 102030 600 mAh | typical crowd (power 0.5) | 233 mA | 2.5 h | 5 % | 3.30 V |
| 102030 600 mAh | packed crowd (power 1.0) | 364 mA | 1.5 h | 7 % | 3.30 V |
| 102030 600 mAh | typical, capped at 60 on battery | 160 mA | 3.6 h | 4 % | 3.30 V |
| 25x30 350 mAh | quiet (few badges, power 0.1) | 128 mA | 2.6 h | 4 % | 3.30 V |
| 25x30 350 mAh | typical crowd (power 0.5) | 233 mA | 1.4 h | 6 % | 3.30 V |
| 25x30 350 mAh | packed crowd (power 1.0) | 364 mA | 0.9 h | 8 % | 3.30 V |
| 25x30 350 mAh | typical, capped at 60 on battery | 160 mA | 2.1 h | 5 % | 3.30 V |

Loads: ESP32-S3 93 mA average (radio receiving, 1 % transmit), LED current per channel 12 mA, heart current by scenario: quiet 35 mA, typical crowd 139 mA, packed crowd 271 mA, typical, capped at 60 on battery 67 mA.
