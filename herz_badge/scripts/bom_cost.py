"""Parts cost per board at production quantities, from bomi's cached LCSC price breaks.

Runs `bomi list` in a board folder, looks up each part's price tiers with `bomi info`, and prints a markdown table:
the per-board cost of each line and the total for 1, 10, 100, 500 and 1000 boards (each part bought at the tier
its total quantity reaches), the unique Extended parts and their per-order fee, and stock against the largest run.
Excludes PCB, assembly and setup fees; JLC's quote has those.

    python3 scripts/bom_cost.py boards/badge            # refresh first: (cd boards/badge && bomi list --check)
"""
import json
import subprocess
import sys

RUNS = (1, 10, 100, 500, 1000)
EXTENDED_FEE = 3.0          # JLC charges about $3 per unique Extended part per order


def bomi(args, cwd):
    out = subprocess.run(["bomi", *args, "--format", "json"], cwd=cwd, capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def unit_price(tiers, qty):
    price = tiers[0]["unit_price"]
    for t in tiers:
        if qty >= t["qty_from"]:
            price = t["unit_price"]
    return price


def main():
    cwd = sys.argv[1] if len(sys.argv) > 1 else "."
    lines = bomi(["list"], cwd)["data"]
    per_part = {}
    for e in lines:
        per_part.setdefault(e["lcsc"], {"qty": 0, "refs": []})
        per_part[e["lcsc"]]["qty"] += e["quantity"]
        per_part[e["lcsc"]]["refs"].append(e["ref"])
    rows, ext = [], []
    for lcsc, p in per_part.items():
        info = bomi(["info", lcsc], cwd)["results"][0]
        tiers = sorted(info["prices"], key=lambda t: t["qty_from"])
        costs = [p["qty"] * unit_price(tiers, p["qty"] * n) for n in RUNS]
        rows.append((costs, lcsc, info["mfr_part"], ", ".join(p["refs"]), p["qty"], info["stock"], info["library_type"]))
        if info["library_type"] != "base" and not info.get("preferred"):
            ext.append(info["mfr_part"])
    rows.sort(key=lambda r: -r[0][-1])
    head = " | ".join(f"{n} boards" for n in RUNS)
    print(f"| Part | LCSC | Refs | Per board | {head} | Stock |")
    print("| --- | --- | --- | --- |" + " --- |" * len(RUNS) + " --- |")
    for costs, lcsc, mpn, refs, qty, stock, lib in rows:
        flag = " (short for 1000)" if stock < qty * RUNS[-1] else ""
        print(f"| {mpn} | {lcsc} | {refs} | {qty} | " + " | ".join(f"${c:.3f}" for c in costs) + f" | {stock:,}{flag} |")
    totals = [sum(r[0][i] for r in rows) for i in range(len(RUNS))]
    print("| **Total per board** | | | | " + " | ".join(f"**${t:.2f}**" for t in totals) + " | |")
    fee = EXTENDED_FEE * len(ext)
    print(f"\nExtended parts: {len(ext)} unique, about ${fee:.0f} per order "
          + "(" + ", ".join(f"${fee / n:.2f}" for n in RUNS) + f" per board at {', '.join(map(str, RUNS))}).")
    print("Extended: " + ", ".join(sorted(ext)))


if __name__ == "__main__":
    main()
