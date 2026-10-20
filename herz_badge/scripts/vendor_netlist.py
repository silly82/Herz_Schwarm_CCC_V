"""Extract the netlist of the Waveshare ESP32-S3-Matrix from its schematic PDF.

The PDF is an Altium export whose bookmark tree lists every component with its pins and every net with its pins
(Altium writes this for cross-probing). Reading the bookmarks gives the exact netlist, without tracing wires on
the drawing. Output: design/reference-netlist.json, {"components": {ref: [pins]}, "nets": {name: ["REF-PIN"]}},
plus a summary on stdout.

    curl -L -o /tmp/ESP32-S3-Matrix-Sch.pdf https://files.waveshare.com/wiki/ESP32-S3-Matrix/ESP32-S3-Matrix-Sch.pdf
    uv run --no-project --with pypdf python scripts/vendor_netlist.py /tmp/ESP32-S3-Matrix-Sch.pdf

The PDF is not kept in the repo (Waveshare's document); the file this was made from is 177828 bytes, created
2024-03-25, sha256 in design/reference-netlist.json.
"""
import hashlib
import json
import os
import re
import sys

from pypdf import PdfReader

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "design", "reference-netlist.json")


def outline(path):
    """[(depth, title)] of the PDF bookmark tree."""
    out = []

    def walk(items, depth):
        for it in items:
            if isinstance(it, list):
                walk(it, depth + 1)
            else:
                out.append((depth, it.title))
    walk(PdfReader(path).outline, 0)
    return out


def netlist(path):
    comps, nets, sec, cur, sub = {}, {}, None, None, None
    for d, t in outline(path):
        t = t.strip()
        if d == 2:
            sec = t
        elif sec == "Components":
            if d == 3:
                cur = comps.setdefault(t, [])
            elif d == 4:
                cur.append(t.split("-", 1)[1])
        elif sec == "Nets":
            if d == 3:
                cur = nets.setdefault(t, [])
            elif d == 4:
                sub = t
            elif d == 5 and sub == "Pins":
                cur.append(t)
    return comps, nets


def main():
    pdf = sys.argv[1]
    comps, nets = netlist(pdf)
    sha = hashlib.sha256(open(pdf, "rb").read()).hexdigest()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"source": "https://files.waveshare.com/wiki/ESP32-S3-Matrix/ESP32-S3-Matrix-Sch.pdf",
                   "sha256": sha, "made_by": "scripts/vendor_netlist.py",
                   "components": comps, "nets": nets}, f, indent=1)
    led = re.compile(r"^U([1-9]|[1-4]\d|5\d|6[0-5])-")   # U1..U65 except U49 (the LDO) are the LEDs
    for name, pins in nets.items():
        other = [p for p in pins if not led.match(p) or p.startswith("U49-")]
        n = len(pins) - len(other)
        print(f"{name:12s} {' '.join(other)}" + (f"  +{n} LED pins" if n else ""))
    print(f"{len(comps)} components, {len(nets)} nets -> {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
