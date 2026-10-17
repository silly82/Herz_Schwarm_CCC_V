"""Build boards/reference/: the Waveshare ESP32-S3-Matrix redrawn in KiCad from its own netlist.

Every pin's net comes from design/reference-netlist.json (made by scripts/vendor_netlist.py from Waveshare's
schematic PDF); this script only adds positions, symbols, footprints and part numbers. The vendor's reference
designators are kept, so the KiCad netlist can be compared one-to-one: scripts/check_reference.py does that.

Three sheets under the root: power.kicad_sch (USB-C, diode, LDO), mcu.kicad_sch (ESP32-S3, crystal, RF, IMU,
buttons, header), leds.kicad_sch (level shifter, 64 LEDs, extension pads). The sheets are regenerated from
scratch on every run; nothing on this board is hand-edited.

    python3 scripts/sch_reference.py && python3 scripts/check_reference.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from builder import *  # noqa: F401,F403  (build, P2, mark_dnp, Konnect, P, ROOT)
import builder

ROOT = builder.ROOT
BOARD = ROOT + "boards/reference/"
VENDOR = json.load(open(ROOT + "design/reference-netlist.json"))

# ---- vendor nets -> schematic nets ---------------------------------------------------------------------------
# Rails become power symbols, nets that cross sheets become global labels, unnamed vendor nets get readable names,
# and every single-pin vendor net is a no-connect.
RENAME = {"GND": "GND", "3V3": "+3V3", "VCC_5V": "+5V", "VBUS": "VBUS",
          "NetC6_1": "RF_ANT", "NetC8_1": "XTAL_P_X", "NetJ1_A5": "CC1", "NetJ1_B5": "CC2", "NetP1_12": "TX_HDR"}
GLOBAL = {"USB_N": "bidirectional", "USB_P": "bidirectional", "IO14": "output"}
PIN2NET = {}
for net, pins in VENDOR["nets"].items():
    for p in pins:
        ref, pin = p.split("-", 1)
        PIN2NET[(ref, pin)] = "NC" if len(pins) == 1 else RENAME.get(net, net)

# vendor pin -> KiCad symbol pin(s), where the numbering differs
USB_PINS = {"A1/B12": ("A1", "B12"), "A12/B1": ("A12", "B1"), "A4/B9": ("A4", "B9"), "A9/B4": ("A9", "B4"),
            "MTB": ("SH",)}
LED_PINS = {"1": "4", "2": "1", "3": "2", "4": "3"}   # vendor VDD/DOUT/VSS/DIN -> WS2812B-2020 DOUT=1 VSS=2 DIN=3 VDD=4
D_PINS = {"1": "2", "2": "1"}                          # vendor 1 = VBUS side (anode) -> Device:D_Schottky A=2, K=1
PIN_MAP = {"J1": USB_PINS, "D1": D_PINS}


def kicad_pins(ref):
    """{kicad pin: net} for a vendor part, from the vendor netlist."""
    m = LED_PINS if ref in LEDS else PIN_MAP.get(ref, {})
    out = {}
    for vpin in VENDOR["components"][ref]:
        kp = m.get(vpin, vpin)
        for k in (kp if isinstance(kp, tuple) else (kp,)):
            out[k] = PIN2NET[(ref, vpin)]
    return out


# ---- parts: ref -> (lib_id, value, footprint, LCSC, extra fields) ---------------------------------------------
R04, C04, C06, L04 = ("Resistor_SMD:R_0402_1005Metric", "Capacitor_SMD:C_0402_1005Metric",
                      "Capacitor_SMD:C_0603_1608Metric", "Inductor_SMD:L_0402_1005Metric")
PARTS = {
    "R1": ("Device:R", "5.1k", R04, "C25905"), "R2": ("Device:R", "5.1k", R04, "C25905"),
    "R3": ("Device:R", "4.7k", R04, "C25900"), "R4": ("Device:R", "2.2k", R04, "C25879"),
    "R5": ("Device:C", "0.5pF", C04, "C1544", {"Note": "a capacitor despite its R designator (vendor naming)"}),
    "R6": ("Device:R", "499", R04, "C4125"), "R7": ("Device:R", "22", R04, "C25092"),
    "R8": ("Device:R", "10k", R04, "C25744"), "R9": ("Device:R", "22", R04, "C25092"),
    "R10": ("Device:R", "10k", R04, "C25744"),
    "C1": ("Device:C", "2.2uF", C04, "C12530"), "C2": ("Device:C", "10uF", C06, "C19702"),
    "C3": ("Device:C", "100nF", C04, "C1525"), "C4": ("Device:C", "10uF", C06, "C19702"),
    "C5": ("Device:C", "1uF", C04, "C52923"), "C6": ("Device:C", "NC", C04, ""), "C7": ("Device:C", "NC", C04, ""),
    "C8": ("Device:C", "10pF", C04, "C32949"), "C9": ("Device:C", "1uF", C04, "C52923"),
    "C10": ("Device:C", "10uF", C06, "C19702"), "C11": ("Device:C", "100nF", C04, "C1525"),
    "C12": ("Device:C", "10pF", C04, "C32949"), "C13": ("Device:C", "100nF", C04, "C1525"),
    "C14": ("Device:C", "100nF", C04, "C1525"), "C15": ("Device:C", "10nF", C04, "C15195"),
    "C16": ("Device:C", "1uF", C04, "C52923"), "C17": ("Device:C", "100nF", C04, "C1525"),
    "C18": ("Device:C", "100nF", C04, "C1525"),
    "IND1": ("Device:L", "2nH", L04, "C76769"), "L1": ("Device:L", "24nH", L04, "C74301"),
    "D1": ("Device:D_Schottky", "B5819WS", "Diode_SMD:D_SOD-323", "C64886"),
    "U49": ("Regulator_Linear:AP2112K-3.3", "ME6217C33M5G", "Package_TO_SOT_SMD:SOT-23-5", "C427602",
            {"Note": "ME6217C33M5G on the AP2112K-3.3 symbol: same SOT-23-5 pinout (VIN, GND, EN, NC, VOUT)"}),
    "Q1": ("Transistor_FET:DMG1012T", "DMG1012T-7", "Package_TO_SOT_SMD:SOT-523", "C20512"),
    "U66": ("MCU_Espressif:ESP32-S3", "ESP32-S3FH4R2", "Package_DFN_QFN:QFN-56-1EP_7x7mm_P0.4mm_EP4x4mm", "C3013940",
            {"Note": "4 MB flash and 2 MB PSRAM in the package"}),
    "U67": ("herz_badge:QMI8658A", "QMI8658C", "Package_LGA:LGA-14_3x2.5mm_P0.5mm_LayoutBorder3x4y", "C2842151",
            {"LCSC_Alt": "C3021082", "Note": "QMI8658C out of stock at JLC (2026-10-17); QMI8658A is the stocked variant"}),
    "Y1": ("Device:Crystal_GND24", "40MHz", "Crystal:Crystal_SMD_3225-4Pin_3.2x2.5mm", "C426988",
           {"Note": "package size not confirmed on the vendor board"}),
    "J1": ("Connector:USB_C_Receptacle_USB2.0_16P", "USB-C", "Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12",
           "C165948", {"Note": "vendor connector type not identified; HRO TYPE-C-31-M-12 as a stand-in"}),
    "J2": ("Device:Antenna_Chip", "CA-C03", "", "", {"Note": "CrossAir CA-C03 2.4 GHz chip antenna, 5.2x2.0 mm; footprint TBD"}),
    "Key1": ("Switch:SW_Push", "RESET", "Button_Switch_SMD:SW_SPST_TS-1088-xR020", "C455280"),
    "Key2": ("Switch:SW_Push", "BOOT", "Button_Switch_SMD:SW_SPST_TS-1088-xR020", "C455280"),
    "P1": ("Connector_Generic:Conn_01x20", "Header", "", "",
           {"Note": "two rows of 10 at 2.54 mm, rows 22.86 mm apart; pins 1-10 down the left edge, 11-20 up the right"}),
    "TP1": ("Connector:TestPoint", "DOUT", "TestPoint:TestPoint_Pad_D1.0mm", ""),
    "TP2": ("Connector:TestPoint", "5V", "TestPoint:TestPoint_Pad_D1.0mm", ""),
    "TP3": ("Connector:TestPoint", "GND", "TestPoint:TestPoint_Pad_D1.0mm", ""),
}
DNP = ["C6", "C7"]

# LED chain from the vendor netlist: LED_DIN -> DIN of the first LED, DOUT -> DIN of the next, ...
LEDS = [r for r in VENDOR["components"] if r.startswith("U") and r not in ("U49", "U66", "U67")]
_din = {n: p.split("-")[0] for n, ps in VENDOR["nets"].items() for p in ps if p.split("-")[0] in LEDS and p.endswith("-4")}
CHAIN, _n = [], "LED_DIN"
while _n in _din:
    CHAIN.append(_din[_n])
    _n = next(n for n, ps in VENDOR["nets"].items() if f"{CHAIN[-1]}-2" in ps)
assert len(CHAIN) == 64, CHAIN
for r in LEDS:
    PARTS[r] = ("LED:WS2812B-2020", "WS2812B", "LED_SMD:LED_WS2812B-2020_PLCC4_2.0x2.0mm", "C52917434",
                {"Note": "vendor part is a WS2812B in an 0807 package; WS2812B-2020-V6 is the stocked equivalent"})


def part(ref, x, y, rot=0, pins=None):
    lib, val, fp, lcsc, *f = PARTS[ref]
    pins = pins if pins is not None else kicad_pins(ref)
    if lib in ("Device:C", "Device:R") and rot == 0 and pins.get("1") == "GND":
        rot = 180   # vendor pin 1 is the ground end: turn it so ground points down
    return dict(ref=ref, lib=lib, val=val, fp=fp, x=x, y=y, rot=rot, lcsc=lcsc, fields=f[0] if f else {}, pins=pins)


def flag(n, net, x, y):
    return dict(ref=f"#FLG{n:02d}", lib="power:PWR_FLAG", x=x, y=y, pins={"1": net})


# ---- sheet: power (USB-C, VBUS diode, LDO) --------------------------------------------------------------------
POWER_SHEET = [
    part("J1", 63.5, 101.6),
    part("C1", 111.76, 76.2), part("R2", 111.76, 134.62), part("R1", 124.46, 134.62),
    part("D1", 144.78, 63.5, rot=180),
    part("C3", 165.1, 111.76), part("C4", 177.8, 111.76),
    part("U49", 208.28, 101.6),
    part("C2", 236.22, 111.76),
    flag(1, "VBUS", 124.46, 50.8), flag(2, "+5V", 165.1, 50.8), flag(3, "GND", 124.46, 165.1),
]

# ---- sheet: mcu (ESP32-S3 and its support, IMU, buttons, header) -----------------------------------------------
MCU_SHEET = [
    part("U66", 203.2, 147.32),
    # 3V3 decoupling, VDD3P3 filter
    part("C9", 101.6, 50.8), part("C10", 114.3, 50.8), part("C13", 127.0, 50.8), part("C14", 139.7, 50.8),
    part("C15", 152.4, 50.8), part("C16", 165.1, 50.8),
    part("IND1", 185.42, 50.8, rot=90), part("C11", 203.2, 50.8),
    flag(4, "VDD3V3", 203.2, 38.1),
    # reset and boot
    part("R8", 50.8, 106.68), part("Key1", 68.58, 121.92, rot=90),
    part("R10", 50.8, 160.02), part("Key2", 68.58, 175.26, rot=90),
    # RF: pi network (C7 shunt, R5 series, C6 shunt) to the chip antenna
    part("C7", 50.8, 238.76), part("R5", 68.58, 226.06, rot=90), part("C6", 86.36, 238.76),
    part("J2", 104.14, 218.44),
    # USB series resistors
    part("R7", 137.16, 251.46, rot=90), part("R9", 137.16, 264.16, rot=90),
    # 40 MHz crystal with the 24 nH series inductor on XTAL_P
    part("L1", 271.78, 210.82, rot=90), part("Y1", 299.72, 226.06),
    part("C12", 284.48, 243.84), part("C8", 314.96, 243.84),
    # IMU
    part("C17", 289.56, 50.8), part("C18", 302.26, 50.8), part("U67", 340.36, 99.06),
    # header and its TX resistor
    part("R6", 337.82, 177.8, rot=90), part("P1", 383.54, 175.26),
]

# ---- sheet: leds (level shifter, 8x8 matrix, extension pads) ---------------------------------------------------
X0, DX, Y0, DY = 124.46, 35.56, 38.1, 27.94
LED_SHEET = [
    part("R4", 40.64, 78.74), part("Q1", 58.42, 66.04), part("R3", 66.04, 45.72), part("C5", 83.82, 66.04),
    part("TP1", 45.72, 254.0), part("TP2", 60.96, 254.0), part("TP3", 76.2, 254.0),
]
WIRES = []
for i, ref in enumerate(CHAIN):
    row, col = divmod(i, 8)
    x, y = X0 + col * DX, Y0 + row * DY
    pins = kicad_pins(ref)
    if col < 7:   # DOUT -> next LED's DIN in the same row: a wire, not a label
        pins["1"] = None
        WIRES.append((x + 7.62, y, x + DX - 7.62, y))
    if col > 0:
        pins["3"] = None
    LED_SHEET.append(part(ref, x, y, pins=pins))


def root_sheet():
    """Rewrite the root with the three sheet blocks; child files are recreated blank."""
    root = BOARD + "reference.kicad_sch"
    txt = open(root).read()
    uuid = txt.split('(uuid "', 1)[1].split('"', 1)[0]
    open(root, "w").write(
        f'(kicad_sch (version 20250114) (generator "pcbkit") (generator_version "10.0") (uuid "{uuid}")\n'
        '\t(paper "A4")\n\t(title_block (title "Waveshare ESP32-S3-Matrix, reverse-engineered reference") '
        '(date "2026-10-17") (rev "vendor 2024-03-25") (company "Herz-Schwarm")\n'
        '\t\t(comment 1 "Generated by scripts/sch_reference.py from design/reference-netlist.json")\n'
        '\t\t(comment 2 "Vendor reference designators kept; see DESIGN.md section 2"))\n'
        '\t(lib_symbols)\n\t(sheet_instances (path "/" (page "1")))\n\t(embedded_fonts no)\n)\n')
    for f in ("power.kicad_sch", "mcu.kicad_sch", "leds.kicad_sch"):
        if os.path.exists(BOARD + f):
            os.remove(BOARD + f)
    k = Konnect()
    k.load("sch_hierarchy", "sch_components")
    for i, (name, f, size) in enumerate([("Power", "power.kicad_sch", "A4"), ("MCU", "mcu.kicad_sch", "A3"),
                                         ("LEDs", "leds.kicad_sch", "A3")]):
        k.call("add_hierarchical_sheet", {"schematic": root, "sheet_file": f, "sheet_name": name,
                                          "x": 30.48 + 81.28 * i, "y": 63.5, "width": 60.96, "height": 30.48})
        k.call("set_schematic_page", {"schematic": BOARD + f, "size": size})
    k.call("renumber_sheet_pages", {"schematic": root})


def check_coverage():
    """Every vendor part is placed exactly once (M1, a pinless logo, is skipped)."""
    placed = [c["ref"] for c in POWER_SHEET + MCU_SHEET + LED_SHEET if not c["ref"].startswith("#")]
    vendor = [r for r, pins in VENDOR["components"].items() if pins]
    assert sorted(placed) == sorted(vendor), (set(vendor) - set(placed), set(placed) - set(vendor))


if __name__ == "__main__":
    check_coverage()
    root_sheet()
    build("power.kicad_sch", base=100, comps=POWER_SHEET, hier={}, glob=GLOBAL)
    build("mcu.kicad_sch", base=200, comps=MCU_SHEET, hier={}, glob=GLOBAL)
    mark_dnp("mcu.kicad_sch", DNP)
    build("leds.kicad_sch", base=300, comps=LED_SHEET, hier={}, glob=GLOBAL, wires=WIRES)
