"""Locate the arduino-cli binary (macOS, Linux, Windows)."""

from __future__ import annotations

import os
import shutil
from typing import List, Optional


def _fallback_paths() -> List[str]:
    """Known install paths when arduino-cli is not on PATH."""
    paths = [
        # macOS Arduino IDE bundle
        "/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli",
        "/usr/local/bin/arduino-cli",
        "/opt/homebrew/bin/arduino-cli",
        os.path.expanduser("~/Arduino/bin/arduino-cli"),
        os.path.expanduser("~/.local/bin/arduino-cli"),
    ]
    if os.name == "nt":
        for base in (os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)")):
            if base:
                paths.append(os.path.join(base, "Arduino CLI", "arduino-cli.exe"))
        local = os.environ.get("LOCALAPPDATA")
        if local:
            paths.append(
                os.path.join(local, "Programs", "Arduino IDE", "resources", "app", "lib",
                             "backend", "resources", "arduino-cli.exe")
            )
    return paths


def find_cli() -> Optional[str]:
    """Locate arduino-cli. Env ARDUINO_CLI first, then PATH, then known locations."""
    env = os.environ.get("ARDUINO_CLI")
    if env and os.path.isfile(env):
        return env
    p = shutil.which("arduino-cli")
    if p:
        return p
    for path in _fallback_paths():
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None
