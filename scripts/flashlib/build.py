"""arduino-cli compile + upload wrappers."""

from __future__ import annotations

import os
import subprocess
import sys
import threading
from typing import Iterable, List, Optional

from .cli import find_cli

DEBUG_EXTRA_FLAGS = ("-DENABLE_SERIAL_DEBUG=1",)
DEBUG_BOARD_OPTS = ("CDCOnBoot=cdc",)

# Merkt sich im Build-Ordner, ob dort ein Release- oder Debug-Build liegt.
_STAMP_NAME = ".flashlib_build_mode"
UPLOAD_TIMEOUT_S = 180


def _cli() -> Optional[str]:
    """Locate arduino-cli (see flashlib.cli.find_cli)."""
    return find_cli()


def cli_path() -> Optional[str]:
    """Path of arduino-cli, or None if it is not installed."""
    return _cli()


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


def _mode_name(debug: bool) -> str:
    return "debug" if debug else "release"


def mark_build(build_path: str, debug: bool) -> None:
    """Remember which mode the binary in `build_path` was built with."""
    try:
        with open(os.path.join(build_path, _STAMP_NAME), "w", encoding="utf-8") as f:
            f.write(_mode_name(debug) + "\n")
    except OSError:
        pass


def build_state(build_path: str, bin_name: str, debug: bool, sources: Iterable[str]) -> Optional[str]:
    """Why the build in `build_path` cannot be flashed as is — or None if it is current.

    A build is stale if the binary is missing, was built in the other mode
    (release/debug) or is older than one of the existing `sources`.
    """
    bin_path = os.path.join(build_path, bin_name)
    if not os.path.isfile(bin_path):
        return "kein Build vorhanden"
    try:
        with open(os.path.join(build_path, _STAMP_NAME), encoding="utf-8") as f:
            built_mode = f.read().strip()
    except OSError:
        built_mode = ""
    if built_mode != _mode_name(debug):
        return "Build-Modus geändert" if built_mode else "Build-Modus unbekannt"
    bin_mtime = os.path.getmtime(bin_path)
    for src in sources:
        if os.path.isfile(src) and os.path.getmtime(src) > bin_mtime:
            return f"{os.path.basename(src)} geändert"
    return None


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
        ok = subprocess.run([cli] + argv).returncode == 0
    else:
        ok = subprocess.run([cli] + argv, capture_output=True).returncode == 0
    if ok:
        mark_build(build_path, debug)
    return ok


def upload(
    port: str,
    fqbn: str,
    debug: bool,
    build_path: str,
    sketch_dir: str,
    stream: bool = False,
) -> bool:
    """Run `arduino-cli upload`. Returns True on success.

    Note: in stream mode, output is also written to the caller's terminal.
    Use `upload_capture` if you need the combined output as a string.
    """
    cli = _cli()
    if not cli:
        return False
    argv = _upload_argv(port, fqbn, debug, build_path, sketch_dir)
    if stream:
        return subprocess.run([cli] + argv).returncode == 0
    return subprocess.run([cli] + argv, capture_output=True).returncode == 0


def _run_capture(cmd: List[str], echo: bool = True, timeout: Optional[float] = None) -> tuple[bool, str]:
    """Run `cmd`, return (success, combined stdout+stderr).

    With `echo`, the output is passed on to the terminal while the command runs
    (not only after it has finished). After `timeout` seconds the command is killed.
    """
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError as exc:
        return False, str(exc)
    timed_out = threading.Event()

    def _kill() -> None:
        timed_out.set()
        proc.kill()

    timer = threading.Timer(timeout, _kill) if timeout else None
    if timer:
        timer.start()
    chunks: List[str] = []
    try:
        assert proc.stdout is not None
        while True:
            ch = proc.stdout.read(1)
            if not ch:
                break
            chunks.append(ch)
            if echo:
                sys.stdout.write(ch)
                sys.stdout.flush()
        proc.wait()
    finally:
        if timer:
            timer.cancel()
    output = "".join(chunks)
    if timed_out.is_set():
        return False, output + f"\n[abgebrochen nach {timeout:.0f} s]\n"
    return proc.returncode == 0, output


def upload_capture(
    port: str,
    fqbn: str,
    debug: bool,
    build_path: str,
    sketch_dir: str,
    echo: bool = True,
    timeout: Optional[float] = UPLOAD_TIMEOUT_S,
) -> tuple[bool, str]:
    """Run `arduino-cli upload` and capture combined output (stdout+stderr).

    Returns (success, output). With `echo` the output is shown live; switch it off
    when several uploads run at the same time.
    """
    cli = _cli()
    if not cli:
        return False, ""
    argv = _upload_argv(port, fqbn, debug, build_path, sketch_dir)
    return _run_capture([cli] + argv, echo=echo, timeout=timeout)
