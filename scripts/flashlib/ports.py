"""Portable ESP32-S3 port discovery (macOS + Linux)."""

from __future__ import annotations

import glob
import json
import shutil
import subprocess
import sys
from typing import List


def _matches_esp32s3(fqbn: str) -> bool:
    """Match ESP32-S3 or generic esp32_family entries from `arduino-cli board list`."""
    return (
        fqbn == "esp32:esp32:esp32s3"
        or fqbn.endswith(":esp32s3")
        or fqbn == "esp32:esp32:esp32_family"
    )


def _dev_cu_globs() -> List[str]:
    """OS-specific list of glob patterns for serial ports."""
    if sys.platform == "darwin":
        return [
            "/dev/cu.usbmodem*",
            "/dev/cu.usbserial*",
            "/dev/cu.usb*",
            "/dev/cu.wchusbserial*",
            "/dev/cu.SLAB*",
        ]
    if sys.platform.startswith("linux"):
        return ["/dev/ttyUSB*", "/dev/ttyACM*"]
    return []


def _discover_via_arduino_cli() -> List[str]:
    """Try `arduino-cli board list --format json`; return matching ports."""
    cli = shutil.which("arduino-cli")
    if not cli:
        return []
    try:
        out = subprocess.run(
            [cli, "board", "list", "--format", "json"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (subprocess.TimeoutExpired, OSError):
        return []
    if out.returncode != 0:
        return []
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        return []
    ports: List[str] = []
    for item in data.get("detected_ports", []):
        addr = (item.get("port") or {}).get("address")
        if not addr:
            continue
        for b in item.get("matching_boards") or []:
            if _matches_esp32s3(b.get("fqbn") or ""):
                ports.append(addr)
                break
    return sorted(set(ports))


def _discover_via_glob() -> List[str]:
    """Fallback: enumerate OS-specific glob patterns."""
    found: List[str] = []
    for pattern in _dev_cu_globs():
        found.extend(glob.glob(pattern))
    # Filter Bluetooth/console pseudo-ports on macOS
    skip = {"Bluetooth-Incoming-Port", "debug-console", "wlan-debug"}
    cleaned: List[str] = []
    for p in found:
        name = p.removeprefix("/dev/cu.").removeprefix("/dev/tty")
        if name in skip:
            continue
        cleaned.append(p)
    return sorted(set(cleaned))


def discover_ports(include_all_usb: bool = False) -> List[str]:
    """Discover ESP32-S3 candidate serial ports.

    Tries `arduino-cli` first; falls back to OS-specific glob patterns.
    """
    if not include_all_usb:
        via_cli = _discover_via_arduino_cli()
        if via_cli:
            return via_cli
    return _discover_via_glob()
