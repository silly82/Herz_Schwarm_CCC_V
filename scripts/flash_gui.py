#!/usr/bin/env python3
"""Herz-Schwarm Batch-Flasher TUI.

Interaktives Flashen mehrerer ESP32-S3-Badges. Effekt-Steuerung (Modi 1-13)
ist NICHT Teil dieses Tools — die läuft über die Basisstation (MQTT oder
Web-UI Port 80) bzw. die Nerves-App.

Voraussetzungen: arduino-cli; pyserial (unter Windows für die Port-Erkennung).
Läuft unter macOS, Linux und Windows.
"""

from __future__ import annotations

import datetime
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Callable, List, Optional, Tuple

# Add parent dir (scripts/) to path so flashlib is importable
sys.path.insert(0, str(Path(__file__).resolve().parent))

from flashlib import __version__ as FLASHLIB_VERSION
from flashlib import term
from flashlib.build import build_state, cli_path
from flashlib.build import compile as do_compile
from flashlib.build import upload_capture as do_upload_capture
from flashlib.firmware import read_firmware_string
from flashlib.log import Log
from flashlib.mac import _parse_mac as parse_mac
from flashlib.ports import discover_ports, port_exists

# Wird in main() gesetzt (Farben nur im Terminal und ohne NO_COLOR).
USE_ANSI = False

# Repo paths
REPO_ROOT = Path(__file__).resolve().parent.parent
SKETCH_DIR = REPO_ROOT
INO_PATH = REPO_ROOT / "Herz_Schwarm_CCC_V.ino"
OTA_SECRET_PATH = REPO_ROOT / "ota_secret.h"
FQBN = "esp32:esp32:esp32s3"
BUILD_PATH = str(REPO_ROOT / "build_batch_gui")
BIN_NAME = f"{INO_PATH.stem}.ino.bin"
LOG_CSV = REPO_ROOT / "firmware_update_log.csv"
LOG_MD = REPO_ROOT / "firmware_update_log.md"

# Mehr gleichzeitige Uploads bringen an einem USB-Hub nichts mehr.
MAX_PARALLEL = 8

# (Port, Ergebnis wie im Log, MAC oder "")
FlashResult = Tuple[str, str, str]


# ANSI helpers
def _c(code: str, text: str) -> str:
    if not USE_ANSI:
        return text
    return f"\033[{code}m{text}\033[0m"

def C_CYAN(text: str) -> str:   return _c("1;36", text)
def C_YELLOW(text: str) -> str: return _c("1;33", text)
def C_GREEN(text: str) -> str:  return _c("1;32", text)
def C_RED(text: str) -> str:    return _c("1;31", text)
def C_PINK(text: str) -> str:   return _c("1;35", text)
def C_GREY(text: str) -> str:   return _c("0;90", text)
def C_BOLD(text: str) -> str:   return _c("1", text)


def clear_screen() -> None:
    if USE_ANSI:
        print("\033[2J\033[H", end="")


def box(title: str, lines: List[str], paint: Callable[[str], str] = C_CYAN, min_width: int = 60) -> str:
    """Render a box with title and lines (frame width follows the content)."""
    return term.box(title, lines, paint=paint, min_width=min_width)


def pause(msg: str = "Weiter mit Enter…") -> None:
    input(C_GREY(f"\n{msg} "))


def _ts() -> str:
    """Local time with UTC offset, e.g. 2026-11-12 18:30:00 +0100."""
    return datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")


# --- State helpers ---

def firmware_label(debug: bool) -> str:
    try:
        return read_firmware_string(str(INO_PATH), debug)
    except OSError:
        return "?"


def stale_reason(debug: bool) -> Optional[str]:
    """None, wenn der Build im Build-Ordner zum Sketch und zum Modus passt."""
    return build_state(BUILD_PATH, BIN_NAME, debug, [str(INO_PATH), str(OTA_SECRET_PATH)])


def status_lines(state: dict) -> List[str]:
    debug = state["debug"]
    reason = stale_reason(debug)
    build = C_GREEN("aktuell") if reason is None else C_YELLOW(f"wird neu gebaut ({reason})")
    ports = state["ports"]
    port_text = C_BOLD(", ".join(ports)) if ports else C_YELLOW("keine ausgewählt")
    cli = cli_path()
    lines = [
        f"Firmware   {C_BOLD(firmware_label(debug))}  ({'Debug' if debug else 'Release'}"
        f"{', mit Funk-Update' if OTA_SECRET_PATH.exists() else ''})",
        f"Build      {build}",
        f"Ports      {port_text}",
    ]
    if not cli:
        lines.append(C_RED("arduino-cli nicht gefunden — installieren oder ARDUINO_CLI setzen"))
    if state["failed"]:
        lines.append(C_RED(f"Zuletzt fehlgeschlagen: {', '.join(state['failed'])}"))
    return lines


def header(state: dict) -> None:
    clear_screen()
    print(box(
        f"Herz-Schwarm Batch-Flasher v{FLASHLIB_VERSION}",
        status_lines(state) + [C_GREY("Nur Flashen — Effekte über Basisstation oder App")],
        paint=C_PINK,
    ))
    print()


# --- Actions ---

def parse_selection(raw: str, count: int) -> Optional[List[int]]:
    """'all'/'' → alle; '1,3' oder '1 3' oder '2-4' → 0-basierte Indizes; None bei Unsinn."""
    raw = raw.strip().lower()
    if raw in ("all", "a", "alle", ""):
        return list(range(count))
    picked: List[int] = []
    for part in raw.replace(",", " ").split():
        try:
            if "-" in part:
                lo, hi = (int(x) for x in part.split("-", 1))
            else:
                lo = hi = int(part)
        except ValueError:
            return None
        if lo < 1 or hi > count or lo > hi:
            return None
        for i in range(lo - 1, hi):
            if i not in picked:
                picked.append(i)
    return picked


def action_scan(state: dict) -> None:
    """Discover ESP32-S3 ports and let user select a subset."""
    print(C_GREY("Suche ESP32-S3-Ports…"))
    ports = discover_ports()
    hint = ""
    if not ports:
        ports = discover_ports(include_all_usb=True)
        hint = " — alle USB-Seriell-Ports, Board nicht erkannt"
    if not ports:
        print(C_RED("✗ Keine Ports gefunden."))
        print(C_GREY("  Boards per USB verbinden (Datenkabel), seriellen Monitor schließen."))
        if sys.platform == "win32":
            print(C_GREY("  Windows: pyserial muss installiert sein (pip install pyserial)."))
        pause()
        return

    lines = [f"{i+1:>2}. {C_BOLD(p)}" for i, p in enumerate(ports)]
    print(box(f"Gefundene Ports ({len(ports)}){hint}", lines))
    print(C_GREY("Auswahl: Enter = alle, sonst Nummern (1,3 oder 2-4)."))
    picked = parse_selection(input(C_CYAN("› ")), len(ports))
    if picked is None:
        print(C_RED("✗ Ungültige Eingabe — Auswahl unverändert."))
        pause()
        return
    state["ports"] = [ports[i] for i in picked]
    state["failed"] = []


def action_toggle_debug(state: dict) -> None:
    state["debug"] = not state["debug"]


def action_toggle_parallel(state: dict) -> None:
    state["parallel"] = not state["parallel"]


def build(debug: bool) -> bool:
    """Kompilieren mit Live-Ausgabe; meldet das Ergebnis."""
    if not INO_PATH.exists():
        print(C_RED(f"✗ Sketch nicht gefunden: {INO_PATH}"))
        return False
    if not cli_path():
        print(C_RED("✗ arduino-cli nicht gefunden (PATH prüfen oder ARDUINO_CLI setzen)."))
        return False
    ver = firmware_label(debug)
    print(C_CYAN(f"Kompiliere {ver} → {BUILD_PATH}"))
    start = time.monotonic()
    ok = do_compile(FQBN, debug, BUILD_PATH, str(SKETCH_DIR), stream=True)
    secs = time.monotonic() - start
    if ok:
        print(C_GREEN(f"✓ Build OK — {ver} ({secs:.0f} s)"))
    else:
        print(C_RED("✗ Build fehlgeschlagen (siehe Ausgabe oben)"))
    return ok


def action_build(state: dict) -> None:
    build(state["debug"])
    pause()


def flash_one(port: str, debug: bool, echo: bool,
              uploader=do_upload_capture, exists=port_exists) -> FlashResult:
    """Ein Board flashen. Ergebnis-Wörter wie im Log des Bash-Skripts."""
    if not exists(port):
        return port, "skip_no_device", ""
    ok, output = uploader(port, FQBN, debug, BUILD_PATH, str(SKETCH_DIR), echo=echo)
    if not ok:
        return port, "upload_failed", ""
    # esptool nennt die MAC beim Upload — kein zweiter Aufruf nötig
    mac = parse_mac(output)
    return (port, "ok", mac) if mac else (port, "ok_mac_unread", "")


def describe(result: FlashResult) -> str:
    _port, status, mac = result
    if status == "ok":
        return C_GREEN(f"✓ OK — MAC {mac}")
    if status == "ok_mac_unread":
        return C_YELLOW("⚠ geflasht, MAC nicht in der Ausgabe")
    if status == "skip_no_device":
        return C_YELLOW("⚠ Port nicht mehr da — übersprungen")
    return C_RED("✗ Upload fehlgeschlagen")


def flash_ports(ports: List[str], ver: str, debug: bool, log: Log, parallel: bool,
                uploader=do_upload_capture, exists=port_exists, out=print) -> List[FlashResult]:
    """Alle Ports flashen (nacheinander mit Live-Ausgabe oder gleichzeitig), jedes Ergebnis loggen."""
    results: List[FlashResult] = []

    def record(res: FlashResult) -> None:
        results.append(res)
        log.append(_ts(), ver, res[0], res[1], res[2])

    if parallel and len(ports) > 1:
        out(C_GREY(f"  {len(ports)} Uploads gleichzeitig — Ausgabe erst bei Fehlern…"))
        with ThreadPoolExecutor(max_workers=min(len(ports), MAX_PARALLEL)) as pool:
            futures = {pool.submit(flash_one, p, debug, False, uploader, exists): p for p in ports}
            for n, fut in enumerate(as_completed(futures), 1):
                try:
                    res = fut.result()
                except Exception as exc:  # ein Absturz darf die anderen Uploads nicht mitreißen
                    out(C_RED(f"  {futures[fut]}: {exc}"))
                    res = (futures[fut], "upload_failed", "")
                record(res)
                out(f"  [{n}/{len(ports)}] {C_BOLD(res[0])}  {describe(res)}")
        # Reihenfolge wie ausgewählt, nicht wie fertig geworden
        results.sort(key=lambda r: ports.index(r[0]))
    else:
        for i, port in enumerate(ports, 1):
            out()
            out(C_BOLD(f"[{i}/{len(ports)}] {port}"))
            res = flash_one(port, debug, True, uploader, exists)
            record(res)
            out(f"  {describe(res)}")
    return results


def run_flash(state: dict, ports: List[str]) -> None:
    if not ports:
        print(C_RED("✗ Keine Ports ausgewählt. Erst [1] Ports scannen."))
        pause()
        return
    debug = state["debug"]
    reason = stale_reason(debug)
    if reason is not None:
        print(C_YELLOW(f"⚠ Baue neu: {reason}"))
        if not build(debug):
            print(C_RED("✗ Flash abgebrochen."))
            pause()
            return

    ver = firmware_label(debug)
    log = Log(str(LOG_CSV), str(LOG_MD))
    print(C_CYAN(f"Flashe {len(ports)} Board(s) — {ver}"))
    start = time.monotonic()
    results = flash_ports(ports, ver, debug, log, state["parallel"])
    secs = time.monotonic() - start

    good = [r for r in results if r[1].startswith("ok")]
    state["failed"] = [r[0] for r in results if not r[1].startswith("ok")]
    print()
    lines = [f"{C_BOLD(r[0])}  {describe(r)}" for r in results]
    print(box(f"Ergebnis: {len(good)}/{len(results)} geflasht in {secs:.0f} s", lines,
              paint=C_GREEN if not state["failed"] else C_YELLOW))
    print(C_GREY(f"Log: {LOG_CSV.name}, {LOG_MD.name}"))
    if state["failed"]:
        print(C_YELLOW("Fehlgeschlagene Ports lassen sich mit [r] erneut flashen."))
    pause()


def action_flash(state: dict) -> None:
    run_flash(state, list(state["ports"]))


def action_retry(state: dict) -> None:
    run_flash(state, list(state["failed"]))


def action_log(state: dict) -> None:
    log = Log(str(LOG_CSV), str(LOG_MD))
    tail = log.tail_md(20)
    if not tail:
        print(C_GREY("Log ist leer."))
    else:
        print(box("Log (letzte 20 Zeilen)", tail.splitlines() or ["(leer)"], min_width=70))
    pause()


# --- Main loop ---

def menu_items(state: dict) -> List[Tuple[str, str, Optional[Callable[[dict], None]]]]:
    n = len(state["ports"])
    items: List[Tuple[str, str, Optional[Callable[[dict], None]]]] = [
        ("1", "Ports scannen und auswählen", action_scan),
        ("2", f"Build-Modus: {'Debug' if state['debug'] else 'Release'} (umschalten)", action_toggle_debug),
        ("3", "Firmware kompilieren", action_build),
        ("4", f"Flashen ({n} Port{'' if n == 1 else 's'})", action_flash),
        ("5", "Log anzeigen", action_log),
        ("6", f"Gleichzeitig flashen: {'an' if state['parallel'] else 'aus'} (umschalten)",
         action_toggle_parallel),
    ]
    if state["failed"]:
        items.append(("r", f"Fehlgeschlagene erneut flashen ({len(state['failed'])})", action_retry))
    items.append(("q", "Beenden", None))
    return items


def main(argv: Optional[List[str]] = None) -> int:
    global USE_ANSI
    argv = sys.argv[1:] if argv is None else argv
    if "--version" in argv:
        print(f"flashlib {FLASHLIB_VERSION}")
        return 0
    USE_ANSI = term.init_terminal()

    state: dict = {"ports": [], "debug": "--debug" in argv, "parallel": False, "failed": []}
    notice = ""
    while True:
        header(state)
        items = menu_items(state)
        print(box("Hauptmenü", [f"{C_YELLOW(f'[{k}]')} {label}" for k, label, _ in items]))
        if notice:
            print(C_RED(notice))
            notice = ""
        raw = input(C_CYAN("\n› ") + "Auswahl: ").strip().lower()
        match = next((item for item in items if item[0] == raw), None)
        if match is None:
            notice = f"Unbekannte Auswahl: {raw!r}" if raw else ""
            continue
        if match[2] is None:
            print(C_GREY("Bye."))
            return 0
        match[2](state)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, EOFError):
        print()
        print(C_GREY("Abgebrochen."))
        sys.exit(130)
