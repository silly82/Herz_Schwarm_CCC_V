"""Place boards/badge/badge.kicad_pcb from the schematic: outline, footprints with fields and nets, no copper.

Reads the netlist of boards/badge/badge.kicad_sch (kicad-cli), loads every footprint from KiCad's libraries or
lib/herz_badge.pretty, copies value and fields (LCSC, notes, DNP) onto it, links it to its symbol (so a later
"Update PCB from Schematic" matches instead of duplicating), assigns pad nets, places the big and edge parts
where FIXED says and packs the rest next to the pins they serve (PACKED).
The board is rebuilt on every run, so this only works until routing starts; after that, edit positions in KiCad.

Coordinates are board millimetres from the top-left corner, top view (front = LED side), y down. "B" parts sit on
the back. A part with an `aim` gets the rotation that points one of its pads where the board needs it.

    python3 scripts/place_badge.py          # re-runs itself under KiCad's Python
    pcbkit place-score boards/badge/badge.kicad_pcb --png build/ratsnest.png
"""
import os
import subprocess
import sys
import tempfile

KICAD_APP = os.environ.get("PCBKIT_KICAD_APP", "/Applications/KiCad/KiCad.app")
KICAD_PY = os.path.join(KICAD_APP, "Contents/Frameworks/Python.framework/Versions/Current/bin/python3")
try:
    import pcbnew
except ImportError:
    os.execv(KICAD_PY, [KICAD_PY, os.path.abspath(__file__), *sys.argv[1:]])

try:
    import pcbkit  # noqa: F401
except ImportError:  # an interpreter pcbkit is not linked into: use the checkout
    sys.path.insert(0, os.path.expanduser(os.environ.get("PCBKIT_ROOT", "~/src/pcb-kit")))
from pcbkit import sexp
from pcbkit.kicad import KICAD_CLI, data_path, save_board

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
BOARD = ROOT + "boards/badge/"
STOCK = os.path.join(KICAD_APP, "Contents/SharedSupport/footprints")
ORIGIN = (100.0, 100.0)                  # board top-left in KiCad page coordinates
W, H, RADIUS = 30.0, 34.0, 1.0           # outline (DESIGN.md D8, D11: 30 wide for a 103030 cell)
LED_PITCH = 3.2                          # the 2020 footprint's courtyard is 3.2 mm long
LED_X0, LED_Y0 = W / 2 - 3.5 * LED_PITCH, 2.6

# ---- placement ------------------------------------------------------------------------------------------------
# FIXED: ref -> (x, y, side, rotation or aim). aim = (pad, dx, dy): rotate so that pad lies in direction (dx, dy)
# from the footprint centre (the USB-C's pads point into the board, away from the edge its mouth sits on).
FIXED = {
    # bottom strip, below the LEDs: the parts with holes or keep-outs
    "J101": (14.7, 31.0, "B", ("A5", 0, -1)),          # USB-C, mouth over the bottom edge
    "SW101": (25.2, 31.9, "B", ("2", 0, -1)),          # slide switch, lever over the bottom edge
    "AE201": (2.34, 32.26, "B", ("1", 1, 0)),          # Walsin corner layout: 0.91 mm from the edge, fed from the right
    "L203": (5.50, 32.26, "B", 0),                      # its 6.8 nH series match, inside the keep-out
    "D102": (22.8, 28.6, "F", 0), "R104": (25.8, 28.6, "F", 0),
    "TP301": (28.3, 28.6, "F", 0),                      # DOUT pad for a second matrix: no room left on the back   # charge LED, front, below the matrix
    # the big parts behind the matrix
    "U201": (10.2, 19.0, "B", ("1", -1, 1)),           # ESP32-S3, LNA_IN corner toward the antenna
    "J102": (25.0, 12.0, "B", ("MP", 1, 0)),           # JST PH, mouth on the right edge
    "SW201": (3.8, 2.2, "B", 0), "SW202": (26.2, 2.2, "B", 0),   # RESET, BOOT
    "U202": (17.5, 4.6, "B", 0),                       # IMU
}
for i in range(64):                     # chain index i at row i // 8, column i % 8 (row-major, as the firmware)
    r, c = divmod(i, 8)
    FIXED[f"D{301 + i}"] = (LED_X0 + LED_PITCH * c, LED_Y0 + LED_PITCH * r, "F", ("3", -1, 0))  # DIN on the left

# PACKED, in this order: ref -> (anchor, side, rotations). The anchor is (x, y) or (ref, pad); the part goes to the
# free spot nearest it (courtyards on the same side, the board edge, the antenna keep-out).
PACKED = [
    # ESP32-S3: crystal and RF first, then decoupling at the pins it serves
    ("Y201", ("U201", "53"), "B", (0, 90)), ("L201", ("U201", "54"), "B", (0, 90)),
    ("C201", ("Y201", "1"), "B", (0, 90)), ("C202", ("Y201", "3"), "B", (0, 90)),
    ("C213", ("U201", "1"), "B", (0, 90)), ("R207", ("U201", "1"), "B", (90, 0)), ("C215", ("AE201", "1"), "B", (0, 90)),
    ("L202", ("U201", "2"), "B", (90, 0)), ("C203", ("U201", "3"), "B", (90, 0)),
    ("C205", ("U201", "46"), "B", (90, 0)), ("C206", ("U201", "46"), "B", (90, 0)),
    ("C204", ("U201", "20"), "B", (0, 90)), ("C207", ("U201", "55"), "B", (0, 90)),
    ("C208", ("U201", "20"), "B", (0, 90)), ("C209", ("U201", "55"), "B", (0, 90)),
    ("C211", ("U201", "29"), "B", (90, 0)), ("C212", ("U201", "29"), "B", (90, 0)),
    ("R201", ("U201", "4"), "B", (0, 90)), ("C210", ("U201", "4"), "B", (0, 90)), ("R202", ("U201", "5"), "B", (0, 90)),
    ("R203", ("U201", "25"), "B", (90, 0)), ("R204", ("U201", "26"), "B", (90, 0)),
    ("R107", ("U201", "6"), "B", (0, 90)), ("R108", ("U201", "6"), "B", (0, 90)), ("C108", ("U201", "6"), "B", (0, 90)),
    ("R109", ("U201", "7"), "B", (0, 90)), ("R110", ("U201", "7"), "B", (0, 90)),
    # USB-C
    ("D101", (23.0, 27.6), "B", (0, 90)),             # first: the SOD-123FL needs the strip above the switch
    ("U103", ("J101", "A6"), "B", (0, 90)),
    ("C101", ("J101", "A4"), "B", (0, 90)), ("R101", ("J101", "A5"), "B", (0, 90)), ("R102", ("J101", "B5"), "B", (0, 90)),
    # power, right column under the JST
    ("Q103", ("J102", "2"), "B", (0, 90)),
    ("U101", (24.5, 20.0), "B", (0, 90)), ("C102", ("U101", "4"), "B", (0, 90)), ("C103", ("U101", "3"), "B", (0, 90)),
    ("R103", ("U101", "5"), "B", (0, 90)),
    ("Q101", (23.0, 24.0), "B", (0, 90)), ("R105", ("Q101", "1"), "B", (0, 90)), ("D104", ("Q101", "2"), "B", (0, 90)),
    ("Q102", (27.5, 24.0), "B", (0, 90)), ("R106", ("Q102", "1"), "B", (0, 90)),
    ("U102", (17.0, 11.5), "B", (0, 90)), ("C105", ("U102", "1"), "B", (0, 90)), ("C106", ("U102", "3"), "B", (0, 90)),
    ("C107", ("U102", "5"), "B", (0, 90)),
    # IMU
    ("C216", ("U202", "5"), "B", (0, 90)), ("C217", ("U202", "8"), "B", (0, 90)),
    ("R205", ("U202", "14"), "B", (0, 90)), ("R206", ("U202", "13"), "B", (0, 90)),
    # LED data and rail
    ("U301", (9.0, 3.0), "B", (0, 90)), ("C301", ("U301", "1"), "B", (0, 90)), ("C302", ("U301", "6"), "B", (0, 90)),
    ("R301", ("U301", "4"), "B", (0, 90)),
    ("C311", (13.0, 9.0), "B", (0, 90)), ("C312", (13.0, 10.5), "B", (0, 90)),
    *[(f"C3{3 + r:02d}", (2.0, LED_Y0 + LED_PITCH * r + 1.6), "B", (90, 0)) for r in range(8)],
    # pads
    ("TP201", (17.0, 24.5), "B", (0,)), ("TP202", (17.0, 24.5), "B", (0,)), ("TP203", (17.0, 24.5), "B", (0,)),
    ("TP204", (17.0, 24.5), "B", (0,)),
]
KEEPOUT = (0.0, 28.0, 6.0, H)           # antenna: 6 x 6 mm, no copper pour or vias on any layer, no other parts
ANTENNA_KEEPOUT = [(KEEPOUT[0], KEEPOUT[1]), (KEEPOUT[2], KEEPOUT[1]), (KEEPOUT[2], KEEPOUT[3]), (KEEPOUT[0], KEEPOUT[3])]


def netlist():
    path = os.path.join(tempfile.mkdtemp(), "badge.net")
    subprocess.run([KICAD_CLI, "sch", "export", "netlist", "--format", "kicadsexpr", "-o", path,
                    BOARD + "badge.kicad_sch"], check=True, capture_output=True)
    tree = sexp.parse(open(path).read())
    comps = {}
    for c in sexp.find(sexp.first(tree, "components"), "comp"):
        ref = sexp.first(c, "ref")[1]
        fields = {f[1][1]: (f[2] if len(f) > 2 else "") for f in sexp.find(sexp.first(c, "fields"), "field")}
        props = {p[1][1] for p in sexp.find(c, "property")}
        sheet = sexp.first(sexp.first(c, "sheetpath"), "tstamps")[1]
        comps[ref] = dict(value=sexp.first(c, "value")[1], footprint=sexp.first(c, "footprint")[1], fields=fields,
                          dnp="dnp" in props, no_bom="exclude_from_bom" in props,
                          path=sheet + sexp.first(c, "tstamps")[1])
    nets = {}
    for n in sexp.find(sexp.first(tree, "nets"), "net"):
        name = sexp.first(n, "name")[1]
        nets[name] = [(sexp.first(x, "ref")[1], sexp.first(x, "pin")[1]) for x in sexp.find(n, "node")]
    return comps, nets


def load(fpid):
    lib, name = fpid.split(":", 1)
    d = ROOT + "lib/herz_badge.pretty" if lib == "herz_badge" else os.path.join(STOCK, lib + ".pretty")
    fp = pcbnew.FootprintLoad(d, name)
    assert fp, fpid
    fp.SetFPID(pcbnew.LIB_ID(lib, name))   # FootprintLoad leaves the library nickname empty
    return fp


def mm(x, y):
    return pcbnew.VECTOR2I(pcbnew.FromMM(ORIGIN[0] + x), pcbnew.FromMM(ORIGIN[1] + y))


def pad_dir(fp, num):
    pads = [p for p in fp.Pads() if p.GetNumber() == num]
    c = fp.GetPosition()
    px = sum(p.GetPosition().x for p in pads) / len(pads) - c.x
    py = sum(p.GetPosition().y for p in pads) / len(pads) - c.y
    return px, py


def place(fp, x, y, side, rot):
    fp.SetPosition(mm(x, y))
    if side == "B" and not fp.IsFlipped():
        fp.Flip(fp.GetPosition(), pcbnew.FLIP_DIRECTION_LEFT_RIGHT)
    if isinstance(rot, tuple):
        num, dx, dy = rot
        best = max((0, 90, 180, 270), key=lambda a: (fp.SetOrientationDegrees(a),
                                                      sum(u * v for u, v in zip(pad_dir(fp, num), (dx, dy))))[1])
        rot = best
    fp.SetOrientationDegrees(rot)


def bmm(v):
    """KiCad internal units -> board mm (from the board's top-left)."""
    return pcbnew.ToMM(v.x) - ORIGIN[0], pcbnew.ToMM(v.y) - ORIGIN[1]


def courtyard(fp):
    """Courtyard bounding box in board mm: (left, top, right, bottom)."""
    if hasattr(fp, "BuildCourtyardCaches"):
        fp.BuildCourtyardCaches()
    cy = fp.GetCourtyard(pcbnew.B_CrtYd if fp.IsFlipped() else pcbnew.F_CrtYd)
    bb = cy.BBox() if cy.OutlineCount() else fp.GetBoundingBox(False)
    l, t = bmm(pcbnew.VECTOR2I(bb.GetLeft(), bb.GetTop()))
    r, b = bmm(pcbnew.VECTOR2I(bb.GetRight(), bb.GetBottom()))
    return l, t, r, b


def holes(fp):
    """Drilled pads (THT and NPTH) as boxes in board mm: they reach the other side too."""
    out = []
    for p in fp.Pads():
        if p.GetAttribute() in (pcbnew.PAD_ATTRIB_PTH, pcbnew.PAD_ATTRIB_NPTH):
            bb = p.GetBoundingBox()
            l, t = bmm(pcbnew.VECTOR2I(bb.GetLeft(), bb.GetTop()))
            r, b = bmm(pcbnew.VECTOR2I(bb.GetRight(), bb.GetBottom()))
            out.append((l, t, r, b))
    return out


def anchor_xy(board, anchor):
    if isinstance(anchor[0], str):
        fp = board.FindFootprintByReference(anchor[0])
        pads = [p for p in fp.Pads() if p.GetNumber() == anchor[1]]
        return (sum(bmm(p.GetPosition())[0] for p in pads) / len(pads),
                sum(bmm(p.GetPosition())[1] for p in pads) / len(pads))
    return anchor


STEP, REACH = 0.2, 14.0
UNPLACED = []
SPIRAL = sorted(((dx * STEP, dy * STEP) for dx in range(-int(REACH / STEP), int(REACH / STEP) + 1)
                 for dy in range(-int(REACH / STEP), int(REACH / STEP) + 1)), key=lambda d: d[0] ** 2 + d[1] ** 2)


def pack(board, fp, anchor, side, rots, taken):
    """Put fp at the free spot nearest the anchor, trying each rotation; record its box in `taken`."""
    ax, ay = anchor_xy(board, anchor)
    best = None
    for rot in rots:
        place(fp, ax, ay, side, rot)
        l, t, r, b = courtyard(fp)
        cx, cy = bmm(fp.GetPosition())
        rel = (l - cx, t - cy, r - cx, b - cy)
        for dx, dy in SPIRAL:
            if best and dx * dx + dy * dy >= best[0]:
                break
            x, y = ax + dx, ay + dy
            box = (x + rel[0], y + rel[1], x + rel[2], y + rel[3])
            if box[0] < 0.15 or box[1] < 0.15 or box[2] > W - 0.15 or box[3] > H - 0.15:
                continue
            if side == "B" and box[0] < KEEPOUT[2] and box[3] > KEEPOUT[1]:
                continue
            if any(o[0] in (side, "*") and box[0] < o[3] and o[1] < box[2] and box[1] < o[4] and o[2] < box[3]
                   for o in taken):
                continue
            best = (dx * dx + dy * dy, x, y, rot, box)
            break
    if not best:   # leave it at the anchor; the overlap report names it
        UNPLACED.append(fp.GetReference())
        place(fp, ax, ay, side, rots[0])
        taken.append((side, *courtyard(fp)))
        return
    _, x, y, rot, box = best
    place(fp, x, y, side, rot)
    taken.append((side, *box))


def outline(board):
    w, h, r = W, H, RADIUS
    edge = board.GetLayerID("Edge.Cuts")

    def seg(x1, y1, x2, y2):
        s = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_SEGMENT)
        s.SetStart(mm(x1, y1)); s.SetEnd(mm(x2, y2)); s.SetLayer(edge); s.SetWidth(pcbnew.FromMM(0.05))
        board.Add(s)

    def arc(cx, cy, sx, sy, ex, ey):
        a = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_ARC)
        a.SetCenter(mm(cx, cy)); a.SetStart(mm(sx, sy)); a.SetEnd(mm(ex, ey)); a.SetLayer(edge)
        a.SetWidth(pcbnew.FromMM(0.05))
        board.Add(a)
    seg(r, 0, w - r, 0); seg(w, r, w, h - r); seg(w - r, h, r, h); seg(0, h - r, 0, r)
    arc(r, r, 0, r, r, 0); arc(w - r, r, w - r, 0, w, r); arc(w - r, h - r, w, h - r, w - r, h)
    arc(r, h - r, r, h, 0, h - r)


def keepout(board, pts, name):
    z = pcbnew.ZONE(board)
    z.SetIsRuleArea(True)
    z.SetZoneName(name)
    z.SetLayerSet(pcbnew.LSET.AllCuMask())
    for setter in ("SetDoNotAllowZoneFills", "SetDoNotAllowCopperPour"):
        if hasattr(z, setter):
            getattr(z, setter)(True)
    z.SetDoNotAllowTracks(False); z.SetDoNotAllowVias(True); z.SetDoNotAllowPads(False)
    z.SetDoNotAllowFootprints(False)
    ol = z.Outline()
    ol.NewOutline()
    for x, y in pts:
        ol.Append(pcbnew.FromMM(ORIGIN[0] + x), pcbnew.FromMM(ORIGIN[1] + y))
    board.Add(z)


def text(board, s, x, y, layer, size=0.8):
    t = pcbnew.PCB_TEXT(board)
    t.SetText(s); t.SetPosition(mm(x, y)); t.SetLayer(board.GetLayerID(layer))
    t.SetTextSize(pcbnew.VECTOR2I(pcbnew.FromMM(size), pcbnew.FromMM(size)))
    t.SetTextThickness(pcbnew.FromMM(size * 0.15))
    if layer.startswith("B."):
        t.SetMirrored(True)
    board.Add(t)


def overlaps(board):
    """Pairs of courtyards on the same side whose bounding boxes intersect (a quick check, not DRC)."""
    boxes = []
    for fp in board.GetFootprints():
        side = "B" if fp.IsFlipped() else "F"
        cy = fp.GetCourtyard(pcbnew.B_CrtYd if side == "B" else pcbnew.F_CrtYd)
        if cy.OutlineCount() == 0:
            continue
        bb = cy.BBox()
        boxes.append((fp.GetReference(), side, bb.GetLeft(), bb.GetTop(), bb.GetRight(), bb.GetBottom()))
    out = []
    for fp in board.GetFootprints():
        for h in holes(fp):
            for o in board.GetFootprints():
                if o.GetReference() == fp.GetReference():
                    continue
                l, t, r, bt = courtyard(o)
                if h[0] < r and l < h[2] and h[1] < bt and t < h[3]:
                    out.append((fp.GetReference() + " hole", o.GetReference()))
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if a[1] == b[1] and a[2] < b[4] and b[2] < a[4] and a[3] < b[5] and b[3] < a[5]:
                out.append((a[0], b[0]))
    return out


def refuse_if_open():
    """KiCad writes ~<file>.lck next to files it has open; regenerating under an open editor loses one side's work."""
    import glob
    locks = glob.glob(BOARD + "~*.lck")
    if locks:
        sys.exit("KiCad has this board open (" + ", ".join(os.path.basename(l) for l in locks) + "); close it first")


def main():
    refuse_if_open()
    comps, nets = netlist()
    placed = set(FIXED) | {p[0] for p in PACKED}
    missing = sorted(set(comps) - placed)
    extra = sorted(placed - set(comps))
    assert not missing and not extra, (missing, extra)

    # a fresh board from the kit's template every run (BOARD.Remove() corrupts pcbnew's bindings mid-run)
    board = pcbnew.LoadBoard(data_path("templates", "blank.kicad_pcb"))
    board.SetCopperLayerCount(4)
    ds = board.GetDesignSettings()
    ds.SetAuxOrigin(mm(0, H))            # fab files measure from the bottom-left corner
    ds.SetGridOrigin(mm(0, 0))
    ds.m_CopperEdgeClearance = pcbnew.FromMM(0.3)   # JLC's limit; the template has 0.5

    netinfo = {}
    for name in nets:
        ni = pcbnew.NETINFO_ITEM(board, name)
        board.Add(ni)
        netinfo[name] = ni
    pin_net = {node: name for name, nodes in nets.items() for node in nodes}

    for ref, c in sorted(comps.items()):
        fp = load(c["footprint"])
        fp.SetReference(ref)
        fp.SetValue(c["value"])
        for k, v in c["fields"].items():
            if k != "Footprint":
                fp.SetField(k, v)
                fp.GetField(k).SetVisible(False)
        fp.SetPath(pcbnew.KIID_PATH(c["path"]))
        fp.SetDNP(c["dnp"])
        fp.SetExcludedFromBOM(c["no_bom"])
        board.Add(fp)
        for p in fp.Pads():
            n = pin_net.get((ref, p.GetNumber()))
            if n:
                p.SetNet(netinfo[n])
        if ref in FIXED:
            x, y, side, rot = FIXED[ref]
            place(fp, x, y, side, rot)

    taken = []
    for fp in board.GetFootprints():
        if fp.GetReference() in FIXED:
            taken.append(("B" if fp.IsFlipped() else "F", *courtyard(fp)))
            taken += [("*", *h) for h in holes(fp)]
    # labels that must stay readable (cell polarity, switch position): reserve their space before packing
    labels = [(mark, *anchor_xy(board, ("J102", num)), 1.0) for num, mark in (("2", "+"), ("1", "-"))]
    labels = [(t, x - 2.6, y, size) for t, x, y, size in labels]
    sx, sy = anchor_xy(board, ("SW101", "1"))
    labels.append(("ON", sx, sy - 1.8, 0.8))
    for t, x, y, size in labels:
        half = 0.35 * size * len(t) + 0.3
        taken.append(("B", x - half, y - size / 2 - 0.3, x + half, y + size / 2 + 0.3))
    for ref, anchor, side, rots in PACKED:
        pack(board, board.FindFootprintByReference(ref), anchor, side, rots, taken)

    # designators go to the fab layers (the assembly map shows them); the board is too dense for silk designators
    for fp in board.GetFootprints():
        ref = fp.Reference()
        ref.SetLayer(board.GetLayerID("B.Fab" if fp.IsFlipped() else "F.Fab"))
        ref.SetPosition(fp.GetPosition())
        ref.SetTextSize(pcbnew.VECTOR2I(pcbnew.FromMM(0.45), pcbnew.FromMM(0.45)))
        ref.SetTextThickness(pcbnew.FromMM(0.07))
        fp.Value().SetVisible(False)

    outline(board)
    keepout(board, ANTENNA_KEEPOUT, "antenna keep-out")
    # cell polarity beside the JST pads, on the inner side of the connector
    for t, x, y, size in labels:
        text(board, t, x, y, "B.SilkS", size)
    text(board, "RESET", FIXED["SW201"][0] + 1.0, FIXED["SW201"][1] + 2.5, "B.SilkS", 0.8)
    text(board, "BOOT", FIXED["SW202"][0], FIXED["SW202"][1] + 2.5, "B.SilkS", 0.8)
    text(board, "Herz-Schwarm", 9.0, 30.4, "F.SilkS", 0.9)
    save_board(board, BOARD + "badge.kicad_pcb")

    ov = overlaps(board)
    print(f"{len(comps)} footprints, {len(nets)} nets, board {W} x {H} mm, 4 layers")
    print("courtyard overlaps:", ov if ov else "none")
    if UNPLACED:
        print("no free spot found (left at their anchors):", ", ".join(UNPLACED))


if __name__ == "__main__":
    main()
