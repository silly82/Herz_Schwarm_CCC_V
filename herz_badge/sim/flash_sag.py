"""Does a white flash on a low battery brown out the ESP32-S3? (DESIGN.md section 4)

The virus effect lights all 64 LEDs white, 150 ms on / 150 ms off for 3 s, at the current brightness (worst case
130/255), while the radio may be transmitting. On battery that current runs through the cell's internal
resistance, the JST, Q103, Q101 and Q102 before the LDO. Swept over the state of charge for each cell.
Pass: 3V3 stays above the brownout level down to 5 % charge, where the firmware should have shut down anyway.

    uv run --no-project --with matplotlib python sim/flash_sag.py
"""
import model as m

SOCS = (0.5, 0.2, 0.1, 0.05)
BRIGHTNESS = 130


def flash_current(p=m.P):
    return p["n_led"] * 3 * p["i_ch"] * BRIGHTNESS / 255


def deck(cell, soc):
    p = m.P
    i_base = m.heart_current(m.SCENARIOS["typical crowd (power 0.5)"]["brightness"])
    i_flash = flash_current()
    return f"""badge flash sag
{m.cell(cell['cap_ah'], cell['r_int'], soc)}
{m.battery_path()}
{m.usb_path(vbus_src="DC 0")}
{m.charger()}
{m.switch_and_loads(i_base, p['i_tx'] + p['i_other'])}
Iflash vsw 0 PULSE(0 {i_flash} 0.5 1m 1m 0.15 0.3 10)
.tran 0.5m 3.6 0 1m uic
.meas tran vsw_min MIN v(vsw) FROM=0.5 TO=3.6
.meas tran v3_min MIN v(v3v3) FROM=0.5 TO=3.6
.meas tran ocv FIND v(ocv) AT=0.4
.control
run
wrdata sag.txt v(vsw) v(v3v3)
.endc
.end
"""


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    rows = []
    fig, axes = plt.subplots(1, len(m.CELLS), figsize=(5 * len(m.CELLS), 4), sharey=True)
    for ax, (cname, cell) in zip(axes, m.CELLS.items()):
        for soc in SOCS:
            r = m.spice(deck(cell, soc))
            rows.append((cname, soc, r.meas["ocv"], r.meas["vsw_min"], r.meas["v3_min"]))
            xs, (vsw, v3) = m.wrdata(r.files, "sag.txt")
            ax.plot(xs, v3, label=f"{soc * 100:.0f} %: 3V3 min {r.meas['v3_min']:.2f} V")
        ax.axhline(m.P["v_brownout"], color="red", lw=0.8, ls="--")
        ax.set_title(cname)
        ax.set_xlabel("s")
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    axes[0].set_ylabel("3V3 (V)")
    fig.suptitle(f"Virus flash, 64 LEDs white at {BRIGHTNESS}/255 ({flash_current() * 1000:.0f} mA) while "
                 f"transmitting (sim/flash_sag.py)")
    fig.tight_layout()
    fig.savefig(m.os.path.join(m.RESULTS, "flash_sag.png"), dpi=120)

    lines = ["| Cell | Charge | Open-circuit | VSW min | 3V3 min | Brownout? |", "| --- | --- | --- | --- | --- | --- |"]
    for c, soc, ocv, vsw, v3 in rows:
        lines.append(f"| {c} | {soc * 100:.0f} % | {ocv:.2f} V | {vsw:.2f} V | {v3:.2f} V | "
                     + ("**yes**" if v3 < m.P["v_brownout"] else "no") + " |")
    lines.append(f"\nFlash: {flash_current() * 1000:.0f} mA of LEDs on top of the typical heart "
                 f"({m.heart_current(m.SCENARIOS['typical crowd (power 0.5)']['brightness']) * 1000:.0f} mA) and the "
                 f"radio transmitting ({(m.P['i_tx'] + m.P['i_other']) * 1000:.0f} mA). Brownout level "
                 f"{m.P['v_brownout']:.2f} V.")
    text = "\n".join(lines) + "\n"
    print(text)
    print("wrote", m.save("flash_sag.md", "# White flash on a low battery (sim/flash_sag.py)\n\n" + text))


if __name__ == "__main__":
    main()
