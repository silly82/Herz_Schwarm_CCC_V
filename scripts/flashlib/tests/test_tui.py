"""Tests for the 0.2.0 additions: terminal helpers, build state, streaming capture, TUI logic."""

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import flash_gui  # noqa: E402
from flashlib import term  # noqa: E402
from flashlib.build import _run_capture, build_state, mark_build  # noqa: E402
from flashlib.firmware import read_firmware_version  # noqa: E402
from flashlib.log import Log  # noqa: E402
from flashlib.ports import _discover_via_pyserial, _sorted_unique  # noqa: E402


# --- firmware parser ---

def test_parse_defines_with_trailing_comment(tmp_path):
    # So steht es im echten Sketch; vor 0.2.0 wurden diese Zeilen als 0 gelesen.
    ino = tmp_path / "x.ino"
    ino.write_text(
        "#define FW_VERSION_MAJOR 1\n"
        "#define FW_VERSION_MINOR   8\n"
        "#define FW_VERSION_PATCH   3  // 1.8.3: Kommentar mit Umlaut ä und „Anführung“\n"
        "#define FW_DEBUG_BUILD     7  /* Debug-Zähler */\n",
        encoding="utf-8",
    )
    assert read_firmware_version(str(ino)) == (1, 8, 3, 7)


def test_real_sketch_version_is_read():
    ino = Path(__file__).resolve().parents[3] / "Herz_Schwarm_CCC_V.ino"
    major, _minor, _patch, dbg = read_firmware_version(str(ino))
    assert major >= 1
    assert dbg >= 1  # FW_DEBUG_BUILD trägt im Sketch einen Kommentar


# --- terminal helpers ---

def test_visible_len_ignores_colour_codes():
    assert term.visible_len("\033[1;32mok\033[0m") == 2
    assert term.pad("\033[1mab\033[0m", 5).endswith("   ")


def test_box_lines_have_equal_visible_width():
    out = term.box("Titel", ["\033[1;33m[1]\033[0m kurz", "eine deutlich längere Zeile ohne Farbe"],
                   paint=lambda s: f"\033[36m{s}\033[0m", max_width=80)
    widths = {term.visible_len(line) for line in out.splitlines()}
    assert len(widths) == 1


def test_box_cuts_overlong_lines():
    out = term.box("T", ["x" * 200], max_width=50)
    assert all(term.visible_len(line) == 50 for line in out.splitlines())
    assert "…" in out


# --- ports ---

def test_ports_sort_naturally():
    assert _sorted_unique(["COM10", "COM9", "COM10", "COM3"]) == ["COM3", "COM9", "COM10"]


def test_pyserial_discovery_filters_by_vendor(monkeypatch):
    class P:
        def __init__(self, device, vid):
            self.device, self.vid = device, vid

    fake = [P("COM1", None), P("COM7", 0x303A), P("COM5", 0x1A86), P("COM8", 0x046D)]
    monkeypatch.setattr("flashlib.ports._comports", lambda: fake)
    assert _discover_via_pyserial() == ["COM5", "COM7"]
    assert _discover_via_pyserial(include_all_usb=True) == ["COM5", "COM7", "COM8"]


# --- build state ---

def test_build_state(tmp_path):
    build = tmp_path / "build"
    build.mkdir()
    src = tmp_path / "x.ino"
    src.write_text("// sketch")
    args = (str(build), "x.ino.bin", False, [str(src), str(tmp_path / "fehlt.h")])

    assert build_state(*args) == "kein Build vorhanden"
    (build / "x.ino.bin").write_bytes(b"\xe9")
    assert build_state(*args) == "Build-Modus unbekannt"
    mark_build(str(build), debug=True)
    assert build_state(*args) == "Build-Modus geändert"
    mark_build(str(build), debug=False)
    assert build_state(*args) is None

    later = time.time() + 5
    os.utime(src, (later, later))
    assert build_state(*args) == "x.ino geändert"


# --- streaming capture ---

def test_run_capture_returns_output_and_status():
    ok, out = _run_capture([sys.executable, "-c", "print('MAC: aa:bb:cc:dd:ee:ff')"], echo=False)
    assert ok and "aa:bb:cc:dd:ee:ff" in out
    ok, out = _run_capture([sys.executable, "-c", "import sys; print('kaputt'); sys.exit(2)"], echo=False)
    assert not ok and "kaputt" in out


def test_run_capture_kills_after_timeout():
    start = time.monotonic()
    ok, out = _run_capture([sys.executable, "-c", "import time; time.sleep(30)"], echo=False, timeout=1)
    assert not ok and "abgebrochen" in out
    assert time.monotonic() - start < 15


def test_run_capture_missing_binary():
    ok, _out = _run_capture(["gibt-es-nicht-flashlib-test"], echo=False)
    assert not ok


# --- TUI logic ---

def test_parse_selection():
    assert flash_gui.parse_selection("", 3) == [0, 1, 2]
    assert flash_gui.parse_selection("all", 3) == [0, 1, 2]
    assert flash_gui.parse_selection("1,3", 3) == [0, 2]
    assert flash_gui.parse_selection("2-3 1", 3) == [1, 2, 0]
    assert flash_gui.parse_selection("4", 3) is None
    assert flash_gui.parse_selection("x", 3) is None


def _fake_uploader(port, fqbn, debug, build_path, sketch_dir, echo=True):
    if port == "COM2":
        return False, "A fatal error occurred"
    if port == "COM3":
        return True, "Hard resetting"
    return True, f"MAC: aa:bb:cc:dd:ee:{int(port[3:]):02x}"


def _flash(tmp_path, parallel):
    log = Log(tmp_path / "log.csv", tmp_path / "log.md")
    ports = ["COM1", "COM2", "COM3", "COM4"]
    results = flash_gui.flash_ports(
        ports, "1.8.0", False, log, parallel,
        uploader=_fake_uploader, exists=lambda p: p != "COM4", out=lambda *a: None,
    )
    return results, (tmp_path / "log.csv").read_text(encoding="utf-8")


def test_flash_ports_sequential(tmp_path):
    results, csv = _flash(tmp_path, parallel=False)
    assert results == [
        ("COM1", "ok", "aa:bb:cc:dd:ee:01"),
        ("COM2", "upload_failed", ""),
        ("COM3", "ok_mac_unread", ""),
        ("COM4", "skip_no_device", ""),
    ]
    assert len(csv.splitlines()) == 5  # Kopfzeile + 4 Einträge


def test_flash_ports_parallel_gives_same_results(tmp_path):
    results, csv = _flash(tmp_path, parallel=True)
    assert [r[1] for r in results] == ["ok", "upload_failed", "ok_mac_unread", "skip_no_device"]
    assert [r[0] for r in results] == ["COM1", "COM2", "COM3", "COM4"]
    assert len(csv.splitlines()) == 5


def test_log_is_utf8(tmp_path):
    log = Log(tmp_path / "l.csv", tmp_path / "l.md")
    log.append("2026-11-12 10:00:00 +0100", "1.8.0", "COM3", "ok_mac_unread", "")
    assert "—" in (tmp_path / "l.md").read_bytes().decode("utf-8")
    assert b"\r\n" not in (tmp_path / "l.md").read_bytes()


def test_menu_offers_retry_only_after_failures():
    state = {"ports": ["COM1"], "debug": False, "parallel": False, "failed": []}
    assert "r" not in [k for k, _l, _a in flash_gui.menu_items(state)]
    state["failed"] = ["COM1"]
    assert "r" in [k for k, _l, _a in flash_gui.menu_items(state)]
