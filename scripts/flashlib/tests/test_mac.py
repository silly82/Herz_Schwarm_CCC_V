"""Tests for flashlib.mac — esptool MAC-read parser."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from flashlib.mac import _parse_mac  # noqa: E402


def test_parse_mac_valid():
    out = "MAC: aa:bb:cc:dd:ee:ff"
    assert _parse_mac(out) == "aa:bb:cc:dd:ee:ff"


def test_parse_mac_base():
    out = "Base MAC: AA:BB:CC:11:22:33"
    assert _parse_mac(out) == "aa:bb:cc:11:22:33"


def test_parse_mac_none():
    assert _parse_mac("no mac here") is None


def test_parse_mac_with_prefix_text():
    out = "Chip type: ESP32-S3\nMAC: 12:34:56:78:9a:bc\nDone."
    assert _parse_mac(out) == "12:34:56:78:9a:bc"


def test_parse_mac_write_flash_format():
    # Real esptool write-flash output has the MAC in a column-aligned field
    out = """esptool v5.2.0
Connected to ESP32-S3 on /dev/cu.usbmodem1101:
Chip type:          ESP32-S3 (QFN56) (revision v0.2)
USB mode:           USB-Serial/JTAG
MAC:                3c:0f:02:e4:61:00
"""
    assert _parse_mac(out) == "3c:0f:02:e4:61:00"