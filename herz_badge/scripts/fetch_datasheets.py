"""Download datasheet PDFs for LCSC parts into docs/datasheets/ (git-ignored; the summaries next to them are kept).

LCSC's datasheet URLs (the ones bomi stores) return an HTML viewer, which is why `bomi datasheet --pdf` reports
"not directly downloadable". The page embeds the real file from datasheet.lcsc.com in an iframe; this follows it.

    python3 scripts/fetch_datasheets.py                  # every part in boards/badge's bomi BOM
    python3 scripts/fetch_datasheets.py C127620 C293767  # extra parts (candidates not in the BOM)
"""
import csv
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
OUT = ROOT + "docs/datasheets/"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0"
PASSIVE = re.compile(r"^(CL05|CL10|0402W|0603W|KT-0603)")   # stock R/C/LED datasheets add nothing to the notes


def get(url):
    """curl, not urllib: asdf/pyenv Pythons often have no CA bundle."""
    return subprocess.run(["curl", "-sSL", "--max-time", "60", "-A", UA, url], capture_output=True, check=True).stdout


def bom_parts(board="boards/badge"):
    out = subprocess.run(["bomi", "list", "--format", "csv"], cwd=ROOT + board, capture_output=True, text=True,
                         check=True).stdout
    return {r["LCSC"]: (r["Part"], r["Datasheet"]) for r in csv.DictReader(io.StringIO(out))}


def fetch(lcsc, mpn, page_url):
    name = OUT + f"{lcsc}_{re.sub(r'[^A-Za-z0-9.-]+', '-', mpn)}.pdf"
    if os.path.exists(name):
        return name, "cached"
    page = (get(page_url or f"https://www.lcsc.com/datasheet/{lcsc}.pdf")).decode("utf-8", "replace")
    m = re.search(r'https://datasheet\.lcsc\.com/datasheet/pdf/[0-9a-f]+\.pdf\?productCode=' + lcsc, page)
    if not m:
        return None, "no PDF link on the LCSC page"
    data = get(m.group(0))
    if not data.startswith(b"%PDF"):
        return None, "not a PDF"
    with open(name, "wb") as f:
        f.write(data)
    return name, f"{len(data) // 1024} kB"


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = {k: v for k, v in bom_parts().items() if not PASSIVE.match(v[0])}
    for code in sys.argv[1:]:
        parts.setdefault(code, (code, ""))
    for lcsc, (mpn, url) in sorted(parts.items()):
        try:
            path, note = fetch(lcsc, mpn, url)
        except Exception as e:  # one failed download should not stop the rest
            path, note = None, f"failed: {e}"
        print(f"{lcsc:12s} {mpn:28s} {os.path.relpath(path, ROOT) if path else '-':60s} {note}")


if __name__ == "__main__":
    main()
