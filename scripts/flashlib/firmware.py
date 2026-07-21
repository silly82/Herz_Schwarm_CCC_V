"""Parse FW_VERSION_* and FW_DEBUG_BUILD defines from an Arduino sketch."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Tuple

Version = Tuple[int, int, int, int]  # (major, minor, patch, debug_build)

# FW_DEBUG_BUILD is a sibling of FW_VERSION_*, not a child.
_DEFINE_RE = re.compile(
    r"^\s*#define\s+(FW_VERSION_(?:MAJOR|MINOR|PATCH)|FW_DEBUG_BUILD)\s+(\d+)\s*$",
    re.MULTILINE,
)

_KEY_MAP = {
    "FW_VERSION_MAJOR": "MAJOR",
    "FW_VERSION_MINOR": "MINOR",
    "FW_VERSION_PATCH": "PATCH",
    "FW_DEBUG_BUILD": "DEBUG_BUILD",
}


def read_firmware_version(ino_path: str) -> Version:
    """Read MAJOR/MINOR/PATCH/DEBUG_BUILD from the sketch.

    Missing values default to 0.
    """
    text = Path(ino_path).read_text()
    found = {
        _KEY_MAP[key]: int(val)
        for key, val in _DEFINE_RE.findall(text)
        if key in _KEY_MAP
    }
    return (
        found.get("MAJOR", 0),
        found.get("MINOR", 0),
        found.get("PATCH", 0),
        found.get("DEBUG_BUILD", 0),
    )


def firmware_string(version: Tuple[int, int, int, int], debug: bool) -> str:
    """Format a version tuple for display.

    - release (debug=False): "M.N.P"
    - debug (debug=True):    "M.N.DD+debug"  (DD = zero-padded debug build)
    """
    major, minor, patch, dbg = version
    if debug:
        return f"{major}.{minor}.{dbg:02d}+debug"
    return f"{major}.{minor}.{patch}"


def read_firmware_string(ino_path: str, debug: bool) -> str:
    """Convenience: read + format in one call."""
    return firmware_string(read_firmware_version(ino_path), debug)
