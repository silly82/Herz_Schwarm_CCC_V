"""Portable ESP32-S3 port discovery (macOS, Linux, Windows)."""

from __future__ import annotations

import glob
import json
import os
import re
import subprocess
import sys
from typing import List, Optional

from .cli import find_cli

# USB-Hersteller, hinter denen ein ESP32 stecken kann:
# Espressif (natives USB), Silicon Labs CP210x, WCH CH340/CH9102, FTDI.
_ESP_USB_VIDS = {0x303A, 0x10C4, 0x1A86, 0x0403}


def _find_cli() -> Optional[str]:
    """Locate arduino-cli (see flashlib.cli.find_cli)."""
    return find_cli()


def _matches_esp32s3(fqbn: str) -> bool:
    """Match ESP32-S3 or generic esp32_family entries from `arduino-cli board list`."""
    return (
        fqbn == "esp32:esp32:esp32s3"
        or fqbn.endswith(":esp32s3")
        or fqbn == "esp32:esp32:esp32_family"
    )


def _dev_cu_globs() -> List[str]:
    """OS-specific list of glob patterns for serial ports (empty on Windows)."""
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


def _natural_key(port: str):
    """Sort key so that COM10 comes after COM9 and usbmodem1101 after usbmodem101."""
    return [(0, int(part), "") if part.isdigit() else (1, 0, part.lower())
            for part in re.split(r"(\d+)", port) if part]


def _sorted_unique(ports: List[str]) -> List[str]:
    return sorted(set(ports), key=_natural_key)


def _discover_via_arduino_cli() -> List[str]:
    """Try `arduino-cli board list --format json`; return matching ports."""
    cli = _find_cli()
    if not cli:
        return []
    try:
        out = subprocess.run(
            [cli, "board", "list", "--format", "json"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
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
    return _sorted_unique(ports)


def _discover_via_glob() -> List[str]:
    """Fallback on macOS/Linux: enumerate OS-specific glob patterns."""
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
    return _sorted_unique(cleaned)


def _comports():
    """Port list from pyserial, or None when pyserial is missing."""
    try:
        from serial.tools import list_ports
    except ImportError:
        return None
    try:
        return list(list_ports.comports())
    except Exception:
        return []


def _discover_via_pyserial(include_all_usb: bool = False) -> List[str]:
    """Fallback (the only one on Windows): USB serial ports by vendor ID."""
    ports: List[str] = []
    for p in _comports() or []:
        vid = getattr(p, "vid", None)
        if vid is None:
            continue  # kein USB-Gerät (Bluetooth, eingebauter COM1 …)
        if include_all_usb or vid in _ESP_USB_VIDS:
            ports.append(p.device)
    return _sorted_unique(ports)


def discover_ports(include_all_usb: bool = False) -> List[str]:
    """Discover ESP32-S3 candidate serial ports.

    Tries `arduino-cli` first; falls back to OS-specific glob patterns
    (macOS/Linux) and then to pyserial (Windows: COMx).
    """
    if not include_all_usb:
        via_cli = _discover_via_arduino_cli()
        if via_cli:
            return via_cli
    via_glob = _discover_via_glob()
    if via_glob:
        return via_glob
    return _discover_via_pyserial(include_all_usb)


def port_exists(port: str) -> bool:
    """Is the port still there? Windows COM ports are not files, so ask pyserial."""
    if os.name != "nt":
        return os.path.exists(port)
    ports = _comports()
    if ports is None:
        return True  # ohne pyserial nicht prüfbar — den Upload entscheiden lassen
    return port.upper() in {p.device.upper() for p in ports}
