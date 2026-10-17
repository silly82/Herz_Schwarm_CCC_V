"""How long does the badge run on a charge? (DESIGN.md section 3)

For each shortlisted cell and each firmware scenario: discharge from full with the average load of firmware 1.4.0
(radio always receiving, heart at the scenario's brightness) until VSW reaches the proposed firmware cutoff.
Pass: the 103030 1000 mAh cell lasts at least 5 h in a typical crowd.

    uv run --no-project --with matplotlib python sim/runtime.py
"""
import model as m

T_END = 16 * 3600


def deck(cell, brightness):
    i_led = m.heart_current(brightness)
    i_esp = m.esp_current()
    return f"""badge runtime
{m.cell(cell['cap_ah'], cell['r_int'], 1.0)}
{m.battery_path()}
{m.usb_path(vbus_src="DC 0")}
{m.charger()}
{m.switch_and_loads(i_led, i_esp)}
.tran 2 {T_END} 0 20 uic
.meas tran tcut WHEN v(vsw)={m.P['v_cutoff']} FALL=1
.meas tran soccut FIND v(soc) WHEN v(vsw)={m.P['v_cutoff']} FALL=1
.meas tran v3cut FIND v(v3v3) WHEN v(vsw)={m.P['v_cutoff']} FALL=1
.meas tran ibat_avg AVG i(Vcell) FROM=60 TO=3600
.control
run
wrdata runtime.txt v(vsw) v(soc)
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
        for sname, sc in m.SCENARIOS.items():
            r = m.spice(deck(cell, sc["brightness"]))
            t = r.meas.get("tcut")
            rows.append((cname, sname, r.meas["ibat_avg"] * 1000, t / 3600 if t else None,
                         r.meas.get("soccut"), r.meas.get("v3cut")))
            xs, (vsw, soc) = m.wrdata(r.files, "runtime.txt")
            ax.plot([x / 3600 for x in xs], vsw, label=f"{sname}: {t / 3600:.1f} h" if t else sname)
        ax.axhline(m.P["v_cutoff"], color="grey", lw=0.8, ls="--")
        ax.set_title(cname)
        ax.set_xlabel("hours")
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    axes[0].set_ylabel("VSW (V)")
    fig.suptitle("Badge runtime from full, firmware 1.4.0 average load (sim/runtime.py)")
    fig.tight_layout()
    fig.savefig(m.os.path.join(m.RESULTS, "runtime.png"), dpi=120)

    lines = ["| Cell | Scenario | Battery current | Runtime to VSW 3.4 V | SOC left | 3V3 then |",
             "| --- | --- | --- | --- | --- | --- |"]
    for c, s, i, t, soc, v3 in rows:
        lines.append(f"| {c} | {s} | {i:.0f} mA | " + (f"{t:.1f} h" if t else f"> {T_END / 3600:.0f} h")
                     + f" | {soc * 100:.0f} % | {v3:.2f} V |" if t else f" | | |")
    lines.append(f"\nLoads: ESP32-S3 {m.esp_current() * 1000:.0f} mA average (radio receiving, 1 % transmit), LED "
                 f"current per channel {m.P['i_ch'] * 1000:.0f} mA, heart current by scenario: "
                 + ", ".join(f"{k.split(' (')[0]} {m.heart_current(v['brightness']) * 1000:.0f} mA"
                             for k, v in m.SCENARIOS.items()) + ".")
    text = "\n".join(lines) + "\n"
    print(text)
    print("wrote", m.save("runtime.md", "# Runtime (sim/runtime.py)\n\n" + text), "and sim/results/runtime.png")


if __name__ == "__main__":
    main()
