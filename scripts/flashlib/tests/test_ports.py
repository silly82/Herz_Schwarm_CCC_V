"""Tests for flashlib.ports — portable ESP32-S3 port discovery."""

import sys
from pathlib import Path

# Allow running tests from repo root without installing
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from flashlib.ports import _dev_cu_globs, _matches_esp32s3, discover_ports  # noqa: E402


def test_discover_returns_list():
    assert isinstance(discover_ports(), list)


def test_filter_matches_esp32s3():
    assert _matches_esp32s3("esp32:esp32:esp32s3")
    assert _matches_esp32s3("esp32:esp32:esp32_family")
    assert not _matches_esp32s3("esp32:esp32:esp32")
    assert not _matches_esp32s3("")


def test_dev_cu_glob_darwin():
    if sys.platform == "darwin":
        globs = _dev_cu_globs()
        assert any("usbmodem" in g for g in globs)
        assert any("usbserial" in g for g in globs)
    elif sys.platform.startswith("linux"):
        globs = _dev_cu_globs()
        assert any("ttyUSB" in g for g in globs)
        assert any("ttyACM" in g for g in globs)
    else:
        globs = _dev_cu_globs()
        assert globs == []