"""Compare boards/reference/ with the vendor netlist: same parts, same pins on the same nets.

Exports the KiCad netlist, maps each vendor pin to its KiCad pin(s) (the pin maps live in sch_reference.py), and
checks that every vendor net with two or more pins is exactly one KiCad net with exactly those pins, and that every
single-pin vendor net is an unconnected pin in KiCad. Exit 1 on any difference.

    python3 scripts/check_reference.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sch_reference as ref  # noqa: E402  (pin maps and the vendor netlist; importing does not build anything)
from pcbkit.checks.netlist import Netlist  # noqa: E402


def kicad_pins(r, vpin):
    m = ref.LED_PINS if r in ref.LEDS else ref.PIN_MAP.get(r, {})
    kp = m.get(vpin, vpin)
    return [(r, k) for k in (kp if isinstance(kp, tuple) else (kp,))]


def main():
    n = Netlist(ref.BOARD + "reference.kicad_sch")
    seen = set()
    for vnet, vpins in ref.VENDOR["nets"].items():
        want = {p for vp in vpins for p in kicad_pins(*vp.split("-", 1))}
        got_nets = {n.pin.get(p) for p in want}
        if len(vpins) == 1:
            (p,) = want
            net = n.pin.get(p)
            n.expect(net is None or net.startswith("unconnected") or len(n.nets[net]) == 1,
                     f"{vnet}: {p[0]}-{p[1]} unconnected (KiCad: {net})")
            continue
        ok = len(got_nets) == 1 and None not in got_nets and n.nets[next(iter(got_nets))] == want
        net = next(iter(got_nets)) if len(got_nets) == 1 else sorted(map(str, got_nets))
        extra = sorted(n.nets[net] - want) if ok is False and isinstance(net, str) and net in n.nets else []
        n.expect(ok, f"{vnet} -> {net} ({len(want)} pins)" + (f" extra {extra}" if extra else ""))
        if isinstance(net, str):
            seen.add(net)
    stray = [k for k, v in n.nets.items() if k not in seen and len(v) > 1]
    n.expect(not stray, f"no KiCad nets beyond the vendor's {stray}")
    # the facts DESIGN.md relies on, by name
    n.expect(n.pin[("U66", "19")] == "IO14" and n.pin[("Q1", "2")] == "IO14", "LED data: GPIO14 -> Q1 source")
    n.expect(n.pin[("Q1", "1")] == "+3V3" and n.pin[("R3", "1")] == "+5V", "Q1 gate on 3V3, drain pulled to 5V")
    n.expect(n.pin[("U66", "5")] == n.pin[("Key2", "1")], "BOOT button on GPIO0")
    n.expect(n.pin[("U66", "16")] == n.pin[("U67", "14")] and n.pin[("U66", "17")] == n.pin[("U67", "13")],
             "IMU SDA on GPIO11, SCL on GPIO12")
    n.expect(n.nodes(n.pin[("U66", "4")]) == 3, "CHIP_PU has only R8 and Key1 (no RC capacitor)")
    n.expect(n.pin.get(("U66", "29"), "unconnected").startswith("unconnected"), "VDD_SPI has no decoupling")
    n.finish()


if __name__ == "__main__":
    main()
