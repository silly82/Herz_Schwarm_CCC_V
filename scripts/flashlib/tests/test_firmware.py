"""Tests for flashlib.firmware — version parser."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from flashlib.firmware import firmware_string, read_firmware_version  # noqa: E402


def test_parse_fw_defines(tmp_path):
    # FW_DEBUG_BUILD is NOT FW_VERSION_* — it lives outside the FW_VERSION_ group
    ino = tmp_path / "x.ino"
    ino.write_text(
        """
#define FW_VERSION_MAJOR 1
#define FW_VERSION_MINOR 2
#define FW_VERSION_PATCH 3
#define FW_DEBUG_BUILD 5
"""
    )
    assert read_firmware_version(str(ino)) == (1, 2, 3, 5)


def test_parse_with_extra_whitespace(tmp_path):
    ino = tmp_path / "x.ino"
    ino.write_text("#define   FW_VERSION_MAJOR   2\n#define FW_VERSION_MINOR\t0\n")
    assert read_firmware_version(str(ino)) == (2, 0, 0, 0)


def test_firmware_string_release():
    assert firmware_string((1, 2, 3, 0), debug=False) == "1.2.3"


def test_firmware_string_debug():
    assert firmware_string((1, 2, 3, 5), debug=True) == "1.2.05+debug"


def test_firmware_string_debug_zero_build():
    # debug=0 build → "1.2.00+debug"
    assert firmware_string((1, 2, 3, 0), debug=True) == "1.2.00+debug"
