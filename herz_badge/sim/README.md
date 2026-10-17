# Power-path simulations

Status (2026-10-17): runtime, charging, white-flash sag and USB unplug simulated for three cells; the unplug run
found a brownout, fixed by D104 and R105 = 10k (DESIGN.md D13).

One script per design question, all sharing `model.py` (cell, charger, P-FETs, LDO and the firmware's loads as
current sinks; every datasheet number in it points at `docs/datasheets/*.md`). They run ngspice through
`pcbkit.spice` and write a table (`results/*.md`) and a plot (`results/*.png`).

| Script | Question | Pass |
| --- | --- | --- |
| `runtime.py` | how long a charge lasts, per cell and firmware scenario | 1000 mAh lasts 5 h in a typical crowd |
| `charge.py` | charge time, and how much the TP4056's thermal regulation slows it | 1000 mAh full within 4.5 h |
| `flash_sag.py` | whether the white virus flash browns out the ESP32 on a low battery | 3V3 above brownout down to 5 % |
| `unplug.py` | whether pulling USB while running resets the ESP32 | 3V3 above brownout at 10 % |

```bash
brew install ngspice
uv run --no-project --with matplotlib python sim/runtime.py    # likewise charge.py, flash_sag.py, unplug.py
```

The model leaves out LED PWM ripple (loads are averages, or worst-case steps for the flash), the LDO's control
loop (an ideal regulator with a dropout resistance), temperature except the charger's thermal regulation, and
cell ageing. The cell's open-circuit curve and internal resistance are typical values, not a datasheet of the
cells on the shortlist; a measured discharge of the chosen cell should replace them.
