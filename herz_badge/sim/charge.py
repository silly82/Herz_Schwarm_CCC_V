"""How long does a charge take, and does the TP4056's thermal regulation slow it? (DESIGN.md section 4)

Each shortlisted cell from nearly empty (5 %) on a 5 V USB supply, badge switched off. The charger's die heats by
(VBUS - VBAT) x I; above t_reg it cuts the current. The TP4054 in SOT-23-5 (250 mW absolute maximum) would
have run there for most of a 300 mA charge; the TP4056 in ESOP-8 with its exposed pad on the ground plane does not.
Pass: the 1000 mAh cell is full (charge current below the termination level) within 4.5 h.

    uv run --no-project --with matplotlib python sim/charge.py
"""
import model as m

T_END = 6 * 3600


def deck(cell):
    p = m.P
    return f"""badge charge
{m.cell(cell['cap_ah'], cell['r_int'], 0.05)}
{m.battery_path()}
{m.usb_path(vbus_src="DC 5.0")}
{m.charger()}
{m.switch_and_loads(0, 0)}
.tran 2 {T_END} 0 10 uic
.meas tran i_start FIND i(Vcell) AT=120
.meas tran p_max MAX par('(V(vbus)-V(vbat))*(-i(Vcell))') FROM=10 TO={T_END}
.meas tran t80 WHEN v(soc)=0.8 RISE=1
.meas tran tcv WHEN v(vbat)={p['v_float'] - 0.005} RISE=1
.meas tran tfull WHEN i(Vcell)=-{p['i_term']} RISE=1 TD=600
.meas tran soc_full FIND v(soc) WHEN i(Vcell)=-{p['i_term']} RISE=1 TD=600
.control
run
wrdata charge.txt -i(Vcell) v(vbat) v(soc)
.endc
.end
"""


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    p_max_allowed = (m.P["t_reg"] - m.P["t_amb"]) / m.P["theta_ja"]
    rows = []
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(8, 6), sharex=True)
    for cname, cell in m.CELLS.items():
        r = m.spice(deck(cell))
        g = r.meas.get
        rows.append((cname, -g("i_start") * 1000, g("p_max"), g("tcv") / 3600, g("t80") / 3600,
                     g("tfull") / 3600 if g("tfull") else None, g("soc_full")))
        xs, (ich, vbat, soc) = m.wrdata(r.files, "charge.txt")
        h = [x / 3600 for x in xs]
        a1.plot(h, [i * 1000 for i in ich], label=cname)
        a2.plot(h, [s * 100 for s in soc], label=cname)
    a1.set_ylabel("charge current (mA)")
    a2.set_ylabel("state of charge (%)")
    a2.set_xlabel("hours")
    for a in (a1, a2):
        a.grid(alpha=0.3)
        a.legend(fontsize=8)
    a1.set_title(f"TP4056, R_PROG 3.0k, 5 V USB, badge off; thermal limit {p_max_allowed:.2f} W (sim/charge.py)")
    fig.tight_layout()
    fig.savefig(m.os.path.join(m.RESULTS, "charge.png"), dpi=120)

    lines = ["| Cell | Current at 2 min | Charger heat, peak | CV reached | 80 % | Full (I < I_term) | SOC at end |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for c, i0, pm, tcv, t80, tf, sf in rows:
        lines.append(f"| {c} | {i0:.0f} mA | {pm:.2f} W | {tcv:.1f} h | {t80:.1f} h | "
                     + (f"{tf:.1f} h | {sf * 100:.0f} % |" if tf else "not within 6 h | |"))
    lines.append(f"\nThermal regulation holds the die at {m.P['t_reg']:.0f} degC: with theta_JA {m.P['theta_ja']:.0f} "
                 f"degC/W at {m.P['t_amb']:.0f} degC ambient the charger may dissipate {p_max_allowed:.2f} W, so the "
                 f"current is limited to {p_max_allowed:.2f} W / (VBUS - VBAT) until the cell is above about "
                 f"{5.0 - p_max_allowed / m.P['i_cc']:.2f} V.")
    text = "\n".join(lines) + "\n"
    print(text)
    print("wrote", m.save("charge.md", "# Charging (sim/charge.py)\n\n" + text), "and sim/results/charge.png")


if __name__ == "__main__":
    main()
