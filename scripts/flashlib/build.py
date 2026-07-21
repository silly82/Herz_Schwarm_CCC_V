"""arduino-cli compile + upload wrappers."""

from __future__ import annotations

import shutil
import subprocess
from typing import List, Optional

DEBUG_EXTRA_FLAGS = ("-DENABLE_SERIAL_DEBUG=1",)
DEBUG_BOARD_OPTS = ("CDCOnBoot=cdc",)


def _compile_argv(fqbn: str, debug: bool, build_path: str, sketch_dir: str) -> List[str]:
    """Build argv for `arduino-cli compile`."""
    argv = ["arduino-cli", "compile", "--fqbn", fqbn, "--build-path", build_path]
    if debug:
        argv += ["--board-options", "CDCOnBoot=cdc"]
        argv += ["--build-property", "compiler.cpp.extra_flags=-DENABLE_SERIAL_DEBUG=1"]
    argv += [sketch_dir]
    return argv


def _upload_argv(port: str, fqbn: str, debug: bool, build_path: str, sketch_dir: str) -> List[str]:
    """Build argv for `arduino-cli upload`."""
    argv = ["arduino-cli", "upload", "-p", port, "--fqbn", fqbn]
    if debug:
        argv += ["--board-options", "CDCOnBoot=cdc"]
    argv += ["--input-dir", build_path, sketch_dir]
    return argv


def _cli() -> Optional[str]:
    return shutil.which("arduino-cli")


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
