"""Shared ngspice model of the badge's power path: LiPo cell, TP4056 charger, load-sharing and switch P-FETs,
ME6217 LDO, the LED matrix and the ESP32-S3 as current sinks. The question scripts (charge.py, runtime.py,
flash_sag.py, unplug.py) build decks from it and run them through pcbkit's ngspice runner.

Numbers come from the datasheet summaries in docs/datasheets/*.md (page references there); the ones that are
assumptions say so. Units: volts, amps, ohms, seconds, amp-hours.

What the model leaves out: LED PWM ripple (loads are averages or worst-case steps), the LDO's loop dynamics (it is
an ideal regulator with a dropout resistance), temperature except the charger's thermal regulation, cell ageing.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
try:
    import pcbkit  # noqa: F401
except ImportError:  # an interpreter pcbkit is not linked into: use the checkout
    sys.path.insert(0, os.path.expanduser(os.environ.get("PCBKIT_ROOT", "~/src/pcb-kit")))
from pcbkit.spice import run  # noqa: E402

RESULTS = os.path.join(HERE, "results")
os.makedirs(RESULTS, exist_ok=True)

# ---- parts (datasheet values; see docs/datasheets/<part>.md) ---------------------------------------------------
P = dict(
    # TP4056 (UMW, C725790), R_PROG = 3.0k; docs/datasheets/C725790 pages 5-6
    i_cc=0.400,          # 1200 V / R_PROG (2.4k -> 500 mA, 1.2k -> 1000 mA tested)
    v_float=4.2,         # 4.158 / 4.2 / 4.242 V (TP4054 table; TP4056 the same CV level)
    i_term=0.040,        # C/10
    v_trickle=2.9,       # below this: trickle charge at C/10
    i_trickle=0.040,
    t_reg=120.0,         # die temperature where thermal regulation starts (degC)
    theta_ja=70.0,       # ESOP-8 exposed pad soldered to a 4-layer ground plane with vias (degC/W), assumption
    t_amb=25.0,
    # ME6217C33M5G (C427602): 100 mV typ / 180 mV max dropout at 300 mA (p4); max used
    v_out=3.3, r_dropout=0.6,
    i_q_ldo=100e-6,      # 100 uA typ
    # AO3401A (C15127): 60 mohm typ at Vgs -2.5 V, 47 at -4.5 V (p2); Vth -0.5/-0.9/-1.3 V
    r_ds=0.060, v_th=0.9,
    body_is=6.6e-10, body_n=1.22, body_rs=0.03,   # body diode about 0.6 V at 0.1 A, 0.7 V at 1 A (assumption)
    # D101 SS14L (C190475), fitted to 0.30 V at 0.1 A, 0.42 V at 0.5 A, 0.52 V at 1 A
    d_is=4.8e-5, d_n=1.44, d_rs=0.15,
    # D104 B5819WS (C64886): 0.30 V at 0.1 A, 0.40 V at 0.5 A (p2 curve)
    d104_is=4.2e-5, d104_n=1.44, d104_rs=0.10,
    # WS2812B-2020-V6 (C52917434): 12 mA per channel (p1, p4), 1 uA static with all off (p3)
    i_ch=0.012,
    i_static=1e-6,
    n_led=64,
    # ESP32-S3FH4R2 (C3013940, p62-63) and the rest of the 3V3 load
    i_rx=0.090,          # 88 mA HT20 / 91 mA HT40 receive: the firmware never sleeps the radio
    i_tx=0.190,          # transmit at 13 dBm: not given (only 283-340 mA at 18.5-21 dBm), assumption
    i_other=0.002,       # IMU 0.8 mA, level shifter, pull-ups
    tx_duty=0.01,        # 20 ESP-NOW packets a second, about 0.5 ms on air each
    v_brownout=2.8,      # ESP32-S3 brownout level as the Arduino core sets it: not in the datasheet, assumption
    # board
    r_conn=0.03,         # JST PH contacts and cell leads
    r105=10e3,           # VBUS pull-down, also Q101's gate pull-down (was 100k: VBUS held Q101 off after unplug)
    d104=True,           # Schottky across Q101 (VBAT -> VSYS): catches the load while Q101 turns on
    c_vsw=30e-6,         # C105, C106, C311, C312 at DC bias
    c_vbus=9.4e-6,       # C101, C102
    c_vbat=4.7e-6,       # C103
    v_cutoff=3.4,        # proposed firmware shutdown on VSW (DESIGN.md section 3); keeps the LEDs above their 3.3 V minimum
)

# Cells on the shortlist (Alibaba, 2026-10-17); internal resistance including the protection board, assumption
CELLS = {
    "103030 1000 mAh": dict(cap_ah=1.0, r_int=0.12),
    "102030 600 mAh": dict(cap_ah=0.6, r_int=0.18),
    "25x30 350 mAh": dict(cap_ah=0.35, r_int=0.28),
}

# Open-circuit voltage of a LiCoO2/NMC pouch cell against state of charge at low rate (typical curve, assumption)
OCV = [(0.00, 3.00), (0.02, 3.30), (0.05, 3.50), (0.10, 3.62), (0.15, 3.68), (0.20, 3.72), (0.30, 3.76),
       (0.40, 3.79), (0.50, 3.83), (0.60, 3.87), (0.70, 3.93), (0.80, 4.00), (0.90, 4.08), (1.00, 4.20)]


# ---- what the firmware draws -----------------------------------------------------------------------------------
def heart_current(brightness, p=P):
    """Average LED current of firmware 1.4.0's heart: 40 pixels in (255, 0, 150), pulse between 100 and 255
    (sin8 averages to the middle, 0.696 of full), times FastLED's global brightness (0-255)."""
    duty_per_pixel = (255 + 150) / 255 * 0.696 * brightness / 255
    return 40 * duty_per_pixel * p["i_ch"]


def esp_current(p=P):
    return p["i_rx"] + p["tx_duty"] * (p["i_tx"] - p["i_rx"]) + p["i_other"]


# Brightness = BRIGHT_MIN + power * (BRIGHT_MAX - BRIGHT_MIN), power from the RSSI of nearby badges (0..1)
SCENARIOS = {
    "quiet (few badges, power 0.1)": dict(brightness=4 + 0.1 * 126),
    "typical crowd (power 0.5)": dict(brightness=4 + 0.5 * 126),
    "packed crowd (power 1.0)": dict(brightness=130),
    "typical, capped at 60 on battery": dict(brightness=4 + 0.5 * 56),
}


# ---- deck pieces -----------------------------------------------------------------------------------------------
def cell(cap_ah, r_int, soc0):
    """LiPo: OCV(SOC) behind r_int. SOC is the voltage on a 1 F capacitor, integrated from the cell current.
    The cell's terminal is node `batt`; i(Vcell) > 0 when the cell discharges."""
    pts = ", ".join(f"{s}, {v}" for s, v in OCV)
    return f"""* --- cell: {cap_ah * 1000:.0f} mAh, {r_int * 1000:.0f} mohm
Csoc soc 0 1 IC={soc0}
Bsoc soc 0 I = i(Vcell)/{cap_ah * 3600}
Bocv ocv 0 V = pwl(max(min(V(soc),1),0), {pts})
Rint ocv cellp {r_int}
Vcell cellp batt 0
"""


def battery_path(p=P):
    """JST contacts, Q103 (reverse-polarity guard, fully on), VBAT node with C103."""
    return f"""* --- JST, Q103, VBAT
Rconn batt bin {p['r_conn']}
Rq103 bin vbat {p['r_ds']}
Cvbat vbat 0 {p['c_vbat']}
"""


def usb_path(p=P, vbus_src="DC 5.0", r_cable=0.1):
    """USB source (with cable resistance), VBUS caps and R105, Schottky D101 to VSYS, and Q101 (load sharing):
    channel conductance follows its source-gate voltage (gate on VBUS), plus its body diode from VBAT to VSYS and,
    when p['d104'], a Schottky in parallel with it. R109/R110 (200k) are left out: R105 dominates."""
    return f"""* --- USB, D101, Q101
Vusb usbsrc 0 {vbus_src}
Rcable usbsrc vbus {r_cable}
Rvbusbleed vbus 0 {p['r105']}
Cvbus vbus 0 {p['c_vbus']}
.model dschottky D(IS={p['d_is']} N={p['d_n']} RS={p['d_rs']})
.model dbody D(IS={p['body_is']} N={p['body_n']} RS={p['body_rs']})
.model dd104 D(IS={p['d104_is']} N={p['d104_n']} RS={p['d104_rs']})
D101 vbus vsys dschottky
Dq101 vbat vsys dbody
{"D104 vbat vsys dd104" if p["d104"] else "* no D104"}
Bq101 vbat vsys I = (V(vbat)-V(vsys)) / {p['r_ds']} * 0.5*(1+tanh((V(vsys)-V(vbus)-{p['v_th']}-0.6)/0.2))
"""


def switch_and_loads(i_led, i_esp, p=P):
    """Q102 (on), VSW caps, LEDs and their static current, LDO: ideal regulator with a dropout resistance.
    i_led and i_esp are B-source expressions (constants or functions of time)."""
    i_static = p["n_led"] * p["i_static"]
    return f"""* --- Q102, VSW, loads
Rq102 vsys vsw {p['r_ds']}
Cvsw vsw 0 {p['c_vsw']}
Bled vsw 0 I = ({i_led}) + {i_static}
Bldo vsw 0 I = ({i_esp}) + {p['i_q_ldo']}
B3v3 v3v3 0 V = min({p['v_out']}, V(vsw) - {p['r_dropout']}*({i_esp}))
R3v3 v3v3 0 1meg
"""


def charger(p=P):
    """TP4056 as a current source from VBUS into VBAT: trickle below v_trickle, CC limited by thermal regulation
    (die at t_reg: P = (t_reg - t_amb) / theta_ja), CV at v_float (steep conductance)."""
    p_max = (p["t_reg"] - p["t_amb"]) / p["theta_ja"]
    return f"""* --- TP4056
.param pmax={p_max}
Bchg vbus vbat I = (V(vbus) > 4.0) * (V(vbat) < {p['v_trickle']} ? {p['i_trickle']} :
+ min(min({p['i_cc']}, pmax / max(V(vbus)-V(vbat), 0.05)), max(0, ({p['v_float']} - V(vbat)) / 0.02)))
"""


def save(name, text):
    os.makedirs(RESULTS, exist_ok=True)
    path = os.path.join(RESULTS, name)
    with open(path, "w") as f:
        f.write(text)
    return os.path.relpath(path, os.path.dirname(HERE))


def wrdata(files, name):
    """Parse an ngspice wrdata file: columns are (x, y) pairs; returns the x column and the y columns."""
    rows = [list(map(float, l.split())) for l in files[name].strip().splitlines() if l.strip()]
    xs = [r[0] for r in rows]
    ys = [[r[i] for r in rows] for i in range(1, len(rows[0]), 2)]
    return xs, ys


def spice(deck, **kw):
    r = run(deck, sim_dir=HERE, gear_retry=True, timeout=kw.pop("timeout", 300), **kw)
    if r.aborted:
        raise SystemExit("ngspice aborted: " + r.reason + "\n" + r.out[-3000:])
    return r
