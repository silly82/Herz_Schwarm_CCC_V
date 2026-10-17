"""Does pulling or plugging USB while the badge runs reset the ESP32-S3? (DESIGN.md section 4)

With USB in, the load runs from VBUS through D101 and Q101 is off (its gate sits on VBUS). Unplugged, VBUS decays
through the charger, the charge LED and the divider; VSYS first follows the Schottky down, then Q101's body diode
catches it at VBAT minus a diode drop, and the channel turns on once VBUS is a threshold below VSYS. The cable is a
switch that opens at 5 ms and closes again at 40 ms. Swept over the cell's charge.
Pass: 3V3 stays above the brownout level at 10 % charge.

    uv run --no-project --with matplotlib python sim/unplug.py
"""
import model as m

SOCS = (0.8, 0.3, 0.1)
CELL = "103030 1000 mAh"


def deck(cell, soc):
    p = m.P
    i_led = m.heart_current(m.SCENARIOS["typical crowd (power 0.5)"]["brightness"])
    usb = m.usb_path(vbus_src="DC 5.0").replace("Rcable usbsrc vbus 0.1", "Rcable usbsrc cab 0.1\nSusb cab vbus ctl 0 swusb")
    return f"""badge USB unplug and replug
{m.cell(cell['cap_ah'], cell['r_int'], soc)}
{m.battery_path()}
{usb}
.model swusb SW(VT=0.5 VH=0.1 RON=0.01 ROFF=1e9)
Vctl ctl 0 PWL(0 1 5m 1 5.01m 0 40m 0 40.01m 1)
{m.charger()}
{m.switch_and_loads(i_led, m.esp_current())}
.tran 2u 80m 0 20u uic
.meas tran vsw_min MIN v(vsw) FROM=4m TO=80m
.meas tran v3_min MIN v(v3v3) FROM=4m TO=80m
.meas tran vsys_bat FIND v(vsys) AT=30m
.meas tran vsys_usb FIND v(vsys) AT=4m
.control
run
wrdata unplug.txt v(vbus) v(vsys) v(v3v3)
.endc
.end
"""


def compare_fix():
    """The circuit before the fix (R105 100k, no D104) at the same charge levels, for the design note."""
    saved = dict(m.P)
    m.P.update(r105=100e3, d104=False)
    try:
        return [(soc, m.spice(deck(m.CELLS[CELL], soc)).meas["v3_min"]) for soc in SOCS]
    finally:
        m.P.clear()
        m.P.update(saved)


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    rows = []
    fig, axes = plt.subplots(1, len(SOCS), figsize=(5 * len(SOCS), 4), sharey=True)
    for ax, soc in zip(axes, SOCS):
        r = m.spice(deck(m.CELLS[CELL], soc))
        rows.append((soc, r.meas["vsys_usb"], r.meas["vsys_bat"], r.meas["vsw_min"], r.meas["v3_min"]))
        xs, (vbus, vsys, v3) = m.wrdata(r.files, "unplug.txt")
        ms = [x * 1000 for x in xs]
        ax.plot(ms, vbus, label="VBUS")
        ax.plot(ms, vsys, label="VSYS")
        ax.plot(ms, v3, label=f"3V3 (min {r.meas['v3_min']:.2f} V)")
        ax.axhline(m.P["v_brownout"], color="red", lw=0.8, ls="--")
        ax.set_title(f"{CELL}, {soc * 100:.0f} % charge")
        ax.set_xlabel("ms")
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    axes[0].set_ylabel("V")
    fig.suptitle("USB pulled at 5 ms, plugged back at 40 ms, typical load (sim/unplug.py)")
    fig.tight_layout()
    fig.savefig(m.os.path.join(m.RESULTS, "unplug.png"), dpi=120)

    lines = ["| Charge | VSYS on USB | VSYS on battery | VSW min | 3V3 min | Brownout? |",
             "| --- | --- | --- | --- | --- | --- |"]
    for soc, vu, vb, vsw, v3 in rows:
        lines.append(f"| {soc * 100:.0f} % | {vu:.2f} V | {vb:.2f} V | {vsw:.2f} V | {v3:.2f} V | "
                     + ("**yes**" if v3 < m.P["v_brownout"] else "no") + " |")
    before = compare_fix()
    lines.append("\nBefore the fix (R105 100k, no D104), 3V3 min: " + ", ".join(
        f"{soc * 100:.0f} %: {v:.2f} V" for soc, v in before) + f" (brownout below {m.P['v_brownout']:.2f} V).")
    text = "\n".join(lines) + "\n"
    print(text)
    print("wrote", m.save("unplug.md", f"# USB unplug and replug ({CELL}, sim/unplug.py)\n\n" + text))


if __name__ == "__main__":
    main()
