"""Tests for flashlib.log — CSV + Markdown logger."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from flashlib.log import Log  # noqa: E402


def test_csv_header_created(tmp_path):
    log = Log(csv_path=tmp_path / "l.csv", md_path=tmp_path / "l.md")
    log.append("2026-07-21 18:00:00 +0200", "1.1.0", "/dev/cu.x", "ok", "aa:bb:cc:dd:ee:ff")
    content = (tmp_path / "l.csv").read_text()
    assert content.startswith("timestamp;firmware;port;result;mac")
    assert "2026-07-21 18:00:00 +0200;1.1.0;/dev/cu.x;ok;aa:bb:cc:dd:ee:ff" in content


def test_md_header_created(tmp_path):
    log = Log(csv_path=tmp_path / "l.csv", md_path=tmp_path / "l.md")
    log.append("2026-07-21 18:00:00 +0200", "1.1.0", "/dev/cu.x", "ok", "")
    content = (tmp_path / "l.md").read_text()
    assert "Firmware-Update-Protokoll" in content
    assert "2026-07-21 18:00:00 +0200" in content
    assert "1.1.0" in content


def test_csv_appends_without_repeating_header(tmp_path):
    log = Log(csv_path=tmp_path / "l.csv", md_path=tmp_path / "l.md")
    log.append("t1", "1.0.0", "p1", "ok", "m1")
    log.append("t2", "1.0.0", "p2", "ok_mac_unread", "")
    lines = (tmp_path / "l.csv").read_text().splitlines()
    assert lines[0] == "timestamp;firmware;port;result;mac"
    assert lines[1].endswith("m1")
    assert lines[2].endswith(";")  # empty mac trailing semicolon


def test_md_empty_mac_renders_dash(tmp_path):
    log = Log(csv_path=tmp_path / "l.csv", md_path=tmp_path / "l.md")
    log.append("t1", "1.0.0", "p1", "ok", "")
    content = (tmp_path / "l.md").read_text()
    assert "—" in content  # em-dash for empty MAC