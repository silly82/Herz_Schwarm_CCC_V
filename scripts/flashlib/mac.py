"""esptool MAC-read wrapper for ESP32-S3."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from typing import Optional

_MAC_RE = re.compile(r"(?:Base\s+)?MAC:\s*([0-9a-fA-F:]{17})")


def _parse_mac(text: str) -> Optional[str]:
    """Extract first MAC address from esptool output. Returns lowercase or None."""
    m = _MAC_RE.search(text)
    if not m:
        return None
    return m.group(1).lower()


def _find_esptool(explicit: Optional[str] = None) -> Optional[str]:
    """Locate esptool binary. Env > explicit > PATH."""
    if explicit:
        return explicit
    env = os.environ.get("ESPTOOL")
    if env:
        return env
    for name in ("esptool.py", "esptool"):
        p = shutil.which(name)
        if p:
            return p
    return None


def read_mac(port: str, esptool_path: Optional[str] = None, timeout: int = 10) -> Optional[str]:
    """Read the chip's MAC address via esptool. Returns lowercase MAC or None."""
    tool = _find_esptool(esptool_path)
    if not tool:
        return None
    try:
        res = subprocess.run(
            [tool, "--chip", "esp32s3", "--port", port, "read_mac"],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (subprocess.TimeoutExpired, OSError):
        return None
    out = (res.stdout or "") + "\n" + (res.stderr or "")
    return _parse_mac(out)
