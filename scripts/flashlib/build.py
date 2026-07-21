"""arduino-cli compile + upload wrappers."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from typing import List, Optional

DEBUG_EXTRA_FLAGS = ("-DENABLE_SERIAL_DEBUG=1",)
DEBUG_BOARD_OPTS = ("CDCOnBoot=cdc",)

# Known install paths when arduino-cli is not on PATH (e.g. macOS Arduino IDE bundle).
_FALLBACK_PATHS = [
    "/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli",
    "/usr/local/bin/arduino-cli",
    "/opt/homebrew/bin/arduino-cli",
    os.path.expanduser("~/Arduino/bin/arduino-cli"),
    os.path.expanduser("~/.local/bin/arduino-cli"),
]


def _cli() -> Optional[str]:
    """Locate arduino-cli. PATH first, then known install locations."""
    p = shutil.which("arduino-cli")
    if p:
        return p
    for path in _FALLBACK_PATHS:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


def _compile_argv(fqbn: str, debug: bool, build_path: str, sketch_dir: str) -> List[str]:
    """Build argv (without binary path) for `arduino-cli compile`."""
    argv = ["compile", "--fqbn", fqbn, "--build-path", build_path]
    if debug:
        argv += ["--board-options", "CDCOnBoot=cdc"]
        argv += ["--build-property", "compiler.cpp.extra_flags=-DENABLE_SERIAL_DEBUG=1"]
    argv += [sketch_dir]
    return argv


def _upload_argv(port: str, fqbn: str, debug: bool, build_path: str, sketch_dir: str) -> List[str]:
    """Build argv (without binary path) for `arduino-cli upload`."""
    argv = ["upload", "-p", port, "--fqbn", fqbn]
    if debug:
        argv += ["--board-options", "CDCOnBoot=cdc"]
    argv += ["--input-dir", build_path, sketch_dir]
    return argv


def compile(
    fqbn: str,
    debug: bool,
    build_path: str,
    sketch_dir: str,
    stream: bool = False,
) -> bool:
    """Run `arduino-cli compile`. Returns True on success."""
    cli = _cli()
    if not cli:
        return False
    argv = _compile_argv(fqbn, debug, build_path, sketch_dir)
    if stream:
        return subprocess.run([cli] + argv).returncode == 0
    return subprocess.run([cli] + argv, capture_output=True).returncode == 0


def upload(
    port: str,
    fqbn: str,
    debug: bool,
    build_path: str,
    sketch_dir: str,
    stream: bool = False,
) -> bool:
    """Run `arduino-cli upload`. Returns True on success."""
    cli = _cli()
    if not cli:
        return False
    argv = _upload_argv(port, fqbn, debug, build_path, sketch_dir)
    if stream:
        return subprocess.run([cli] + argv).returncode == 0
    return subprocess.run([cli] + argv, capture_output=True).returncode == 0
