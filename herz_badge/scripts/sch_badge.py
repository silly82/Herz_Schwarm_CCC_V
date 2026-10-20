"""Build boards/badge/: the battery Herz-Schwarm badge (DESIGN.md sections 4 and 8).

The MCU, IMU and LED blocks follow the reference (boards/reference/) with the fixes from DESIGN.md 2.4; the power
block is new: USB-C, TP4054 charger, load-sharing P-FET, slide switch on a P-FET, ME6217 LDO, battery and VBUS
sense. Designators by sheet: 1xx power, 2xx MCU, 3xx LEDs (D301 is chain index 0). Regenerated from scratch on
every run, like the reference; the PCB is placed from its netlist by scripts/place_badge.py.

    python3 scripts/sch_badge.py && pcbkit erc boards/badge/badge.kicad_sch
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import builder  # noqa: E402  (pcbkit.schematic, configured for boards/reference/; re-pointed below)

ROOT = builder.ROOT
BOARD = ROOT + "boards/badge/"
builder.configure(BOARD, power={"VSYS": ("power:VCC", "VSYS", 90), "VSW": ("power:VCC", "VSW", 90),
                                "VBAT": ("power:VCC", "VBAT", 90)})
GLOBAL = {"USB_N": "bidirectional", "USB_P": "bidirectional", "VBAT_SENSE": "output", "VBUS_SENSE": "output",
          "LED_DATA": "input"}

R04, C04, C06 = "Resistor_SMD:R_0402_1005Metric", "Capacitor_SMD:C_0402_1005Metric", "Capacitor_SMD:C_0603_1608Metric"
SOT23, SOT235 = "Package_TO_SOT_SMD:SOT-23", "Package_TO_SOT_SMD:SOT-23-5"
RES = {"0": "C17168", "22": "C25092", "33": "C25105", "1k": "C11702", "3.3k": "C25890", "5.1k": "C25905",
       "3k": "C4211",   # 0603: the Basic 3k is 0603 only
       "10k": "C25744", "100k": "C25741", "1M": "C26083"}
CAP = {"10pF": ("C32949", C04), "12pF": ("C1547", C04), "10nF": ("C15195", C04), "100nF": ("C1525", C04), "1uF": ("C52923", C04),
       "4.7uF": ("C23733", C04), "10uF": ("C19702", C06)}
DNP = ["C213", "C215"]


def R(ref, val, x, y, p1, p2, rot=0):
    fp = "Resistor_SMD:R_0603_1608Metric" if val == "3k" else R04
    return dict(ref=ref, lib="Device:R", val=val, fp=fp, x=x, y=y, rot=rot, lcsc=RES[val], pins={"1": p1, "2": p2})


def C(ref, val, x, y, p1, p2="GND", rot=0):
    lcsc, fp = CAP.get(val, ("", C04))
    return dict(ref=ref, lib="Device:C", val=val, fp=fp, x=x, y=y, rot=rot, lcsc=lcsc, pins={"1": p1, "2": p2})


def part(ref, lib, val, fp, lcsc, x, y, pins, rot=0, fields=None):
    return dict(ref=ref, lib=lib, val=val, fp=fp, x=x, y=y, rot=rot, lcsc=lcsc, fields=fields or {}, pins=pins)


def flag(n, net, x, y):
    return dict(ref=f"#FLG{n:02d}", lib="power:PWR_FLAG", x=x, y=y, pins={"1": net})


# ---- sheet: power -------------------------------------------------------------------------------------------
USB = {p: "GND" for p in ("A1", "B12", "A12", "B1", "SH")}
USB.update({p: "VBUS" for p in ("A4", "B9", "A9", "B4")})
USB.update({"A5": "CC1", "B5": "CC2", "A6": "USB_P", "B6": "USB_P", "A7": "USB_N", "B7": "USB_N", "A8": "NC", "B8": "NC"})
POWER_SHEET = [
    part("J101", "Connector:USB_C_Receptacle_USB2.0_16P", "USB-C", "Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12",
         "C165948", 45.72, 101.6, USB),
    R("R101", "5.1k", 83.82, 127.0, "CC1", "GND"), R("R102", "5.1k", 93.98, 127.0, "CC2", "GND"),
    C("C101", "4.7uF", 83.82, 78.74, "VBUS"),
    part("U103", "Power_Protection:USBLC6-2SC6", "USBLC6-2SC6", "Package_TO_SOT_SMD:SOT-23-6", "C7519", 63.5, 152.4,
         {"1": "USB_N", "2": "GND", "3": "USB_P", "4": "USB_P", "5": "VBUS", "6": "USB_N"},
         fields={"Note": "ST part, rated to 5.25 V on VBUS; the TECH PUBLIC copy (C2827654) is rated 5.0 V (DESIGN.md D12)"}),
    R("R109", "100k", 45.72, 177.8, "VBUS", "VBUS_SENSE"), R("R110", "100k", 45.72, 195.58, "VBUS_SENSE", "GND"),
    # VBUS -> VSYS through the Schottky; the cell joins VSYS through Q101 when VBUS is absent (load sharing)
    part("D101", "Device:D_Schottky", "SS14L", "Diode_SMD:D_SOD-123F", "C190475", 129.54, 63.5,
         {"1": "VSYS", "2": "VBUS"}, rot=180,
         fields={"Note": "SOD-123FL: carries the whole load on USB, up to about 1.4 A during a white flash (DESIGN.md D14)"}),
    part("Q101", "Transistor_FET:AO3401A", "AO3401A", SOT23, "C15127", 129.54, 101.6,
         {"1": "VBUS", "2": "VSYS", "3": "VBAT"}),
    R("R105", "10k", 114.3, 116.84, "VBUS", "GND"),     # 10k, not 100k: VBUS must fall fast for Q101 to take over
    # D104 across Q101: carries the load at a Schottky drop while VBUS decays after unplugging (sim/unplug.py)
    part("D104", "Device:D_Schottky", "B5819WS", "Diode_SMD:D_SOD-323", "C64886", 129.54, 127.0,
         {"1": "VSYS", "2": "VBAT"}),
    # charger
    part("U101", "Battery_Management:TP4056-42-ESOP8", "TP4056", 
         "Package_SO:SOIC-8-1EP_3.9x4.9mm_P1.27mm_EP2.41x3.3mm", "C725790", 129.54, 162.56,
         {"1": "GND", "2": "PROG", "3": "GND", "4": "VBUS", "5": "VBAT", "6": "NC", "7": "CHG_K", "8": "VBUS",
          "9": "GND"},
         fields={"Note": "UMW TP4056: 1200 V / R_PROG -> 400 mA with 3k; TEMP grounded (no NTC); exposed pad to GND "
                         "with vias placed by hand between the front LEDs' pads (DESIGN.md D14)"}),
    R("R103", "3k", 109.22, 177.8, "PROG", "GND"), C("C102", "4.7uF", 114.3, 144.78, "VBUS"),
    C("C103", "4.7uF", 154.94, 172.72, "VBAT"),
    R("R104", "1k", 99.06, 142.24, "VBUS", "CHG_A", rot=90),
    part("D102", "Device:LED", "red", "LED_SMD:LED_0603_1608Metric", "C2286", 99.06, 160.02,
         {"1": "CHG_K", "2": "CHG_A"}, rot=90, fields={"Note": "charge LED, front side"}),
    # cell
    part("J102", "Connector_Generic_MountingPin:Conn_01x02_MountingPin", "LiPo",
         "Connector_JST:JST_PH_S2B-PH-SM4-TB_1x02-1MP_P2.00mm_Horizontal", "C295747", 180.34, 162.56,
         {"1": "GND", "2": "VBAT_IN", "MP": "GND"},
         fields={"Note": "JST PH, pin 2 = +VBAT, pin 1 = GND (Adafruit convention); check each cell with a meter"}),
    # reverse-polarity guard: body diode conducts VBAT_IN -> VBAT, then the channel turns on (gate at GND); a cell
    # plugged in backwards leaves the gate above the source and the FET off (DESIGN.md D12)
    part("Q103", "Transistor_FET:AO3401A", "AO3401A", SOT23, "C15127", 200.66, 162.56,
         {"1": "GND", "2": "VBAT", "3": "VBAT_IN"}),
    R("R107", "1M", 226.06, 116.84, "VBAT", "VBAT_SENSE"), R("R108", "1M", 226.06, 134.62, "VBAT_SENSE", "GND"),
    C("C108", "100nF", 238.76, 134.62, "VBAT_SENSE"),
    # off switch: Q102 in series with the load, its gate on the slide switch (the switch only carries gate current)
    part("Q102", "Transistor_FET:AO3401A", "AO3401A", SOT23, "C15127", 175.26, 63.5,
         {"1": "SW_GATE", "2": "VSYS", "3": "VSW"}),
    R("R106", "100k", 160.02, 78.74, "VSYS", "SW_GATE"),
    part("SW101", "Switch:SW_SPDT", "POWER", "Button_Switch_SMD:SW_SPDT_Shouhan_MSK12C02", "C431540", 157.48, 99.06,
         {"1": "GND", "2": "SW_GATE", "3": "NC"}, fields={"Note": "on = common (2) to GND"}),
    # 3V3
    part("U102", "Regulator_Linear:AP2112K-3.3", "ME6217C33M5G", SOT235, "C427602", 251.46, 63.5,
         {"1": "VSW", "2": "GND", "3": "VSW", "4": "NC", "5": "+3V3"},
         fields={"Note": "ME6217C33M5G on the AP2112K-3.3 symbol: same SOT-23-5 pinout"}),
    C("C105", "10uF", 223.52, 73.66, "VSW"), C("C106", "100nF", 233.68, 73.66, "VSW"),
    C("C107", "10uF", 274.32, 73.66, "+3V3"),
    flag(1, "VBUS", 83.82, 50.8), flag(2, "VSYS", 147.32, 50.8), flag(3, "VSW", 205.74, 50.8),
    flag(5, "GND", 83.82, 190.5),   # VBAT is driven by the charger's BAT pin
]

# ---- sheet: mcu ---------------------------------------------------------------------------------------------
ESP = {str(p): "NC" for p in range(1, 58)}
ESP.update({"1": "LNA_IN", "2": "VDD3V3", "3": "VDD3V3", "4": "EN", "5": "BOOT", "6": "VBAT_SENSE", "7": "VBUS_SENSE",
            "15": "IMU_INT1", "16": "IMU_SDA", "17": "IMU_SCL", "18": "IMU_INT2", "19": "LED_DATA", "20": "+3V3",
            "25": "U_N", "26": "U_P", "29": "VDD_SPI", "46": "+3V3", "49": "TX", "50": "RX", "53": "XTALN",
            "54": "XTALP", "55": "+3V3", "56": "+3V3", "57": "GND"})
MCU_SHEET = [
    part("U201", "MCU_Espressif:ESP32-S3", "ESP32-S3FH4R2", "Package_DFN_QFN:QFN-56-1EP_7x7mm_P0.4mm_EP4x4mm",
         "C3013940", 203.2, 147.32, ESP, fields={"Note": "4 MB flash, 2 MB PSRAM in the package"}),
    C("C204", "1uF", 101.6, 50.8, "+3V3"), C("C205", "10uF", 114.3, 50.8, "+3V3"),
    C("C206", "100nF", 127.0, 50.8, "+3V3"), C("C207", "100nF", 139.7, 50.8, "+3V3"),
    C("C208", "10nF", 152.4, 50.8, "+3V3"), C("C209", "1uF", 165.1, 50.8, "+3V3"),
    part("L202", "Device:L", "2nH", "Inductor_SMD:L_0402_1005Metric", "C76769", 185.42, 50.8,
         {"1": "+3V3", "2": "VDD3V3"}, rot=90),
    C("C203", "100nF", 203.2, 50.8, "VDD3V3"), flag(6, "VDD3V3", 203.2, 38.1),
    C("C211", "100nF", 228.6, 50.8, "VDD_SPI"), C("C212", "1uF", 241.3, 50.8, "VDD_SPI"),
    flag(7, "VDD_SPI", 241.3, 38.1),   # the chip powers VDD_SPI itself; KiCad's symbol calls the pin an input
    # reset with Espressif's RC, boot button
    R("R201", "10k", 50.8, 106.68, "+3V3", "EN"), C("C210", "1uF", 63.5, 121.92, "EN"),
    part("SW201", "Switch:SW_Push", "RESET", "Button_Switch_SMD:SW_SPST_TS-1088-xR020", "C455280", 81.28, 121.92,
         {"1": "EN", "2": "GND"}, rot=90),
    R("R202", "10k", 50.8, 160.02, "+3V3", "BOOT"),
    part("SW202", "Switch:SW_Push", "BOOT", "Button_Switch_SMD:SW_SPST_TS-1088-xR020", "C455280", 68.58, 175.26,
         {"1": "BOOT", "2": "GND"}, rot=90),
    # RF: pi network for tuning (shunts not fitted, series 0 ohm) to a stocked 3216 chip antenna
    C("C213", "NC", 50.8, 238.76, "LNA_IN"),
    R("R207", "0", 68.58, 226.06, "LNA_IN", "RF_ANT", rot=90),
    C("C215", "NC", 86.36, 238.76, "RF_ANT"),
    part("L203", "Device:L", "6.8nH", "Inductor_SMD:L_0402_1005Metric", "C77110", 96.52, 226.06,
         {"1": "RF_ANT", "2": "ANT_FEED"}, rot=90,
         fields={"Note": "Walsin's series match, at the antenna inside the keep-out; 8.2 nH lowers, 5.6 nH raises the frequency"}),
    part("AE201", "Device:Antenna_Chip", "RFANT3216120A5T", "herz_badge:ANT_Walsin_RFANT3216120A5T", "C127629",
         116.84, 218.44, {"1": "ANT_FEED", "2": "NC"},
         fields={"Note": "corner antenna, 6 x 6 mm keep-out (docs/datasheets/antennas.md); runner-up Kinghelm KH5220-A36 C484543"}),
    R("R203", "22", 137.16, 251.46, "U_N", "USB_N", rot=90), R("R204", "22", 137.16, 264.16, "U_P", "USB_P", rot=90),
    # crystal
    part("L201", "Device:L", "24nH", "Inductor_SMD:L_0402_1005Metric", "C74301", 271.78, 210.82,
         {"1": "XTALP", "2": "XTAL_P_X"}, rot=90),
    part("Y201", "Device:Crystal_GND24", "40MHz", "Crystal:Crystal_SMD_3225-4Pin_3.2x2.5mm", "C426988", 299.72, 226.06,
         {"1": "XTALN", "2": "GND", "3": "XTAL_P_X", "4": "GND"}),
    C("C201", "12pF", 284.48, 243.84, "XTALN"), C("C202", "12pF", 314.96, 243.84, "XTAL_P_X"),   # 10 pF crystal load
    # IMU with I2C pull-ups
    C("C216", "100nF", 289.56, 50.8, "+3V3"), C("C217", "100nF", 302.26, 50.8, "+3V3"),
    R("R205", "10k", 284.48, 99.06, "+3V3", "IMU_SDA"), R("R206", "10k", 294.64, 99.06, "+3V3", "IMU_SCL"),
    part("U202", "herz_badge:QMI8658A", "QMI8658A", "Package_LGA:LGA-14_3x2.5mm_P0.5mm_LayoutBorder3x4y", "C3021082",
         340.36, 99.06, {"1": "GND", "2": "+3V3", "3": "+3V3", "4": "IMU_INT1", "5": "+3V3", "6": "GND", "7": "GND",
                         "8": "+3V3", "9": "IMU_INT2", "10": "NC", "11": "NC", "12": "+3V3", "13": "IMU_SCL",
                         "14": "IMU_SDA"}),
    # programming and debug pads
    *[part(f"TP20{i + 1}", "Connector:TestPoint", n, "TestPoint:TestPoint_Pad_D1.0mm", "", 350.52 + 12.7 * i, 165.1,
           {"1": net}) for i, (n, net) in enumerate([("TX", "TX"), ("RX", "RX"), ("3V3", "+3V3"), ("GND", "GND")])],
]

# ---- sheet: leds --------------------------------------------------------------------------------------------
X0, DX, Y0, DY = 124.46, 35.56, 38.1, 27.94
LED_SHEET = [
    part("U301", "Logic_LevelTranslator:SN74LVC1T45DBV", "SN74LVC1T45DBVR", "Package_TO_SOT_SMD:SOT-23-6", "C7843",
         58.42, 66.04, {"1": "+3V3", "2": "GND", "3": "LED_DATA", "4": "LED_DIN_B", "5": "+3V3", "6": "VSW"}),
    C("C301", "100nF", 38.1, 45.72, "+3V3"), C("C302", "100nF", 78.74, 45.72, "VSW"),
    R("R301", "33", 86.36, 66.04, "LED_DIN_B", "LED_DIN", rot=90),
    C("C311", "10uF", 38.1, 160.02, "VSW"), C("C312", "10uF", 50.8, 160.02, "VSW"),
    *[C(f"C3{3 + r:02d}", "100nF", 38.1 + 12.7 * (r % 4), 190.5 + 20.32 * (r // 4), "VSW") for r in range(8)],
    part("TP301", "Connector:TestPoint", "DOUT", "TestPoint:TestPoint_Pad_D1.0mm", "", 45.72, 254.0, {"1": "DOUT"}),
]
WIRES = []
for i in range(64):
    row, col = divmod(i, 8)
    x, y = X0 + col * DX, Y0 + row * DY
    din = "LED_DIN" if i == 0 else (f"DOUT_{row}" if col == 0 else None)
    dout = "DOUT" if i == 63 else (f"DOUT_{row + 1}" if col == 7 else None)
    if col < 7:
        WIRES.append((x + 7.62, y, x + DX - 7.62, y))
    LED_SHEET.append(part(f"D{301 + i}", "LED:WS2812B-2020", "WS2812B-2020-V6",
                          "herz_badge:LED_WS2812B-2020_PLCC4_2.0x2.0mm_NoSilk", "C52917434", x, y,
                          {"4": "VSW", "2": "GND", "3": din, "1": dout}))


def root_sheet():
    root = BOARD + "badge.kicad_sch"
    uuid = open(root).read().split('(uuid "', 1)[1].split('"', 1)[0]
    open(root, "w").write(
        f'(kicad_sch (version 20250114) (generator "pcbkit") (generator_version "10.0") (uuid "{uuid}")\n'
        '\t(paper "A4")\n\t(title_block (title "Herz-Schwarm Badge, battery") (date "2026-10-17") (rev "0.1-draft") '
        '(company "Herz-Schwarm")\n\t\t(comment 1 "Generated by scripts/sch_badge.py; see DESIGN.md sections 4 and 7"))\n'
        '\t(lib_symbols)\n\t(sheet_instances (path "/" (page "1")))\n\t(embedded_fonts no)\n)\n')
    for f in ("power.kicad_sch", "mcu.kicad_sch", "leds.kicad_sch"):
        if os.path.exists(BOARD + f):
            os.remove(BOARD + f)
    k = builder.Konnect()
    k.load("sch_hierarchy", "sch_components")
    for i, (name, f) in enumerate([("Power", "power.kicad_sch"), ("MCU", "mcu.kicad_sch"), ("LEDs", "leds.kicad_sch")]):
        k.call("add_hierarchical_sheet", {"schematic": root, "sheet_file": f, "sheet_name": name,
                                          "x": 30.48 + 81.28 * i, "y": 63.5, "width": 60.96, "height": 30.48})
        k.call("set_schematic_page", {"schematic": BOARD + f, "size": "A3"})
    k.call("renumber_sheet_pages", {"schematic": root})


def refuse_if_open():
    """KiCad writes ~<file>.lck next to files it has open; regenerating under an open editor loses one side's work."""
    import glob
    locks = glob.glob(BOARD + "~*.lck")
    if locks:
        sys.exit("KiCad has this board open (" + ", ".join(os.path.basename(l) for l in locks) + "); close it first")


if __name__ == "__main__":
    refuse_if_open()
    root_sheet()
    builder.build("power.kicad_sch", base=100, comps=POWER_SHEET, hier={}, glob=GLOBAL)
    builder.build("mcu.kicad_sch", base=200, comps=MCU_SHEET, hier={}, glob=GLOBAL)
    builder.mark_dnp("mcu.kicad_sch", DNP)
    builder.build("leds.kicad_sch", base=300, comps=LED_SHEET, hier={}, glob=GLOBAL, wires=WIRES)
