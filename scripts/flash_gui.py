#!/usr/bin/env python3
"""Herz-Schwarm Batch-Flasher TUI.

Interaktives Flashen mehrerer ESP32-S3-Badges. Effekt-Steuerung (Modes 1-8)
ist NICHT Teil dieses Tools — die läuft über die Basisstation (MQTT oder
Web-UI Port 80).

Voraussetzungen: pyserial, arduino-cli, esptool.py.
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

# Add parent dir (scripts/) to path so flashlib is importable
sys.path.insert(0, str(Path(__file__).resolve().parent))

from flashlib import __version__ as FLASHLIB_VERSION
from flashlib.build import compile as do_compile
from flashlib.build import upload as do_upload
from flashlib.firmware import read_firmware_string, read_firmware_version
from flashlib.log import Log
from flashlib.mac import read_mac
from flashlib.ports import discover_ports

# Disable ANSI escapes if NO_COLOR is set or stdout is not a TTY
USE_ANSI = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None

# Repo paths
REPO_ROOT = Path(__file__).resolve().parent.parent
SKETCH_DIR = REPO_ROOT
INO_PATH = REPO_ROOT / "Herz_Schwarm_CCC_V.ino"
FQBN = "esp32:esp32:esp32s3"
BUILD_PATH = str(REPO_ROOT / "build_batch_gui")
LOG_CSV = REPO_ROOT / "firmware_update_log.csv"
LOG_MD = REPO_ROOT / "firmware_update_log.md"

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


def box(title: str, lines: list[str], color: str = "1;36", width: int = 60) -> str:
    """Render a box with title and lines."""
    inner = width - 4
    top = _c(color, f"┌─[ {title} ]" + "─" * (width - len(title) - 5) + "┐")
    bot = _c(color, "└" + "─" * (width - 2) + "┘")
    body_lines = []
    for l in lines:
        # strip ANSI for length calc (rough: just count visible chars)
        body_lines.append(_c(color, "│ ") + l.ljust(inner) + _c(color, " │"))
    return "\n".join([top, *body_lines, bot])


def header() -> None:
    clear_screen()
    print(C_PINK("╔════════════════════════════════════════════════════════╗"))
    print(C_PINK("║   ❤️  Herz-Schwarm Batch-Flasher  ") +
          C_BOLD(f"v{FLASHLIB_VERSION}".ljust(20)) + C_PINK("                ║"))
    print(C_PINK("║   ") + C_GREY("Flash-Operations only — Effect-Modes via MQTT/Web-UI") + C_PINK("    ║"))
    print(C_PINK("╚════════════════════════════════════════════════════════╝"))
    print()


def pause(msg: str = "Weiter mit Enter…") -> None:
    input(C_GREY(f"\n{msg} "))


def menu(title: str, items: list[tuple[str, str]]) -> int:
    """Show menu, return 0-based index. -1 on invalid."""
    print(box(title, [f"{C_YELLOW(f'[{k}]')} {v}" for k, v in items]))
    raw = input(C_CYAN("\n› ") + "Auswahl: ").strip()
    for i, (k, _) in enumerate(items):
        if raw == k:
            return i
    return -1


# --- Actions ---

def action_scan(state: dict) -> None:
    """Discover ESP32-S3 ports and let user select a subset."""
    print(C_GREY("Suche ESP32-S3-Ports…"))
    ports = discover_ports()
    if not ports:
        print(C_RED("✗ Keine Ports gefunden."))
        print(C_GREY("  Tipp: Boards per USB verbinden oder --all-usb nutzen."))
        pause()
        return

    lines = [f"  {i+1}. {C_BOLD(p)}" for i, p in enumerate(ports)]
    print(box(f"Gefundene Ports ({len(ports)})", lines))

    print(C_GREY("Auswahl: 'all', Komma-getrennte Nummern (1,3), oder eine einzelne."))
    raw = input(C_CYAN("› ")).strip()
    if raw.lower() in ("all", "a", ""):
        state["ports"] = ports
    else:
        try:
            idxs = [int(x.strip()) - 1 for x in raw.split(",") if x.strip()]
            state["ports"] = [ports[i] for i in idxs if 0 <= i < len(ports)]
        except ValueError:
            print(C_RED("✗ Ungültige Eingabe."))
            pause()
            return

    if state["ports"]:
        print(C_GREEN(f"✓ {len(state['ports'])} Port(s) ausgewählt."))
    else:
        print(C_YELLOW("⚠ Keine Ports ausgewählt."))
    pause()


def action_toggle_debug(state: dict) -> None:
    state["debug"] = not state["debug"]
    print(C_GREEN(f"✓ Build-Modus: {'Debug' if state['debug'] else 'Release'}"))
    pause()


def action_build(state: dict) -> None:
    if not INO_PATH.exists():
        print(C_RED(f"✗ Sketch nicht gefunden: {INO_PATH}"))
        pause()
        return
    debug = state["debug"]
    ver = read_firmware_string(str(INO_PATH), debug)
    print(C_CYAN(f"Firmware: {ver}"))
    print(C_GREY(f"Build-Pfad: {BUILD_PATH}"))
    print(C_GREY(f"Kompiliere (stream)…"))
    ok = do_compile(FQBN, debug, BUILD_PATH, str(SKETCH_DIR), stream=True)
    if ok:
        print(C_GREEN(f"✓ Build OK — {ver}"))
    else:
        print(C_RED("✗ Build fehlgeschlagen (siehe Ausgabe oben)"))
    pause()


def action_flash(state: dict) -> None:
    ports = state.get("ports") or []
    if not ports:
        print(C_RED("✗ Keine Ports ausgewählt. Erst [1] Ports scannen."))
        pause()
        return
    debug = state["debug"]
    ver = read_firmware_string(str(INO_PATH), debug)
    log = Log(str(LOG_CSV), str(LOG_MD))

    # Auto-Build wenn noch keine .bin in build_batch_gui/ vorhanden
    bin_path = Path(BUILD_PATH) / f"{INO_PATH.stem}.ino.bin"
    if not bin_path.exists():
        print(C_YELLOW("⚠ Kein Build gefunden — kompiliere zuerst…"))
        ok = do_compile(FQBN, debug, BUILD_PATH, str(SKETCH_DIR), stream=True)
        if not ok:
            print(C_RED("✗ Build fehlgeschlagen — Flash abgebrochen."))
            pause()
            return
        print(C_GREEN("✓ Build OK"))

    print(C_CYAN(f"Flashen {len(ports)} Board(s) — {ver}"))
    for i, port in enumerate(ports, 1):
        print()
        print(C_BOLD(f"[{i}/{len(ports)}] {port}"))
        if not os.path.exists(port):
            print(C_YELLOW(f"  ⚠ Port existiert nicht — skip"))
            log.append(_ts(), ver, port, "skip_no_device", "")
            continue
        print(C_GREY("  Upload…"))
        ok = do_upload(port, FQBN, debug, BUILD_PATH, str(SKETCH_DIR), stream=True)
        if not ok:
            print(C_RED("  ✗ Upload fehlgeschlagen"))
            log.append(_ts(), ver, port, "upload_failed", "")
            continue
        print(C_GREY("  MAC lesen…"))
        time.sleep(1.5)
        mac = read_mac(port)
        if mac:
            print(C_GREEN(f"  ✓ OK — MAC {mac}"))
            log.append(_ts(), ver, port, "ok", mac)
        else:
            print(C_YELLOW("  ⚠ Flash OK, MAC nicht lesbar"))
            log.append(_ts(), ver, port, "ok_mac_unread", "")
    print()
    print(C_GREEN(f"✓ Fertig. Log: {LOG_CSV.name}, {LOG_MD.name}"))
    pause()


def action_log(state: dict) -> None:
    log = Log(str(LOG_CSV), str(LOG_MD))
    tail = log.tail_md(20)
    if not tail:
        print(C_GREY("Log ist leer."))
    else:
        print(box("Log (letzte 20 Zeilen)", tail.splitlines() or ["(leer)"], width=70))
    pause()


def _ts() -> str:
    import datetime
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S %z")


# --- Main loop ---

def main() -> int:
    state: dict = {
        "ports": [],
        "debug": False,
    }
    if INO_PATH.exists():
        try:
            v = read_firmware_version(str(INO_PATH))
            state["fw_version"] = f"{v[0]}.{v[1]}.{v[2]}"
        except Exception:
            state["fw_version"] = "?"

    actions = [
        ("1", "Ports scannen"),
        ("2", f"Build-Modus: {'Debug' if state['debug'] else 'Release'} (toggle)"),
        ("3", "Firmware kompilieren"),
        ("4", f"Flashen ({len(state['ports'])} Port(s))"),
        ("5", "Log anzeigen"),
        ("q", "Beenden"),
    ]
    action_map = [
        lambda: action_scan(state),
        lambda: action_toggle_debug(state),
        lambda: action_build(state),
        lambda: action_flash(state),
        lambda: action_log(state),
    ]

    while True:
        # Rebuild menu label for port count + debug
        actions[1] = ("2", f"Build-Modus: {'Debug' if state['debug'] else 'Release'} (toggle)")
        actions[3] = ("4", f"Flashen ({len(state['ports'])} Port(s))")

        header()
        choice = menu("Hauptmenü", actions)
        if choice == -1:
            continue
        if choice == 5:  # 'q'
            print(C_GREY("Bye."))
            return 0
        action_map[choice]()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, EOFError):
        print()
        print(C_GREY("Abgebrochen."))
        sys.exit(130)
