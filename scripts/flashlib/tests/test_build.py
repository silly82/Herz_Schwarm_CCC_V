"""Tests for flashlib.build — arduino-cli argv builder."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from flashlib.build import _compile_argv, _upload_argv  # noqa: E402


def test_compile_cmd_no_debug():
    argv = _compile_argv("esp32:esp32:esp32s3", debug=False, build_path="/tmp/x", sketch_dir=".")
    assert "arduino-cli" not in argv  # binary is prepended by caller
    assert argv[0] == "compile"
    assert "esp32:esp32:esp32s3" in argv
    assert "--build-path" in argv
    assert "/tmp/x" in argv


def test_compile_cmd_debug():
    argv = _compile_argv("esp32:esp32:esp32s3", debug=True, build_path="/tmp/x", sketch_dir=".")
    assert any("ENABLE_SERIAL_DEBUG=1" in a for a in argv)
    assert any("CDCOnBoot=cdc" in a for a in argv)


def test_upload_uses_input_dir():
    argv = _upload_argv("/dev/cu.usbmodem01", "esp32:esp32:esp32s3", False, "/tmp/x", ".")
    assert "arduino-cli" not in argv
    assert argv[0] == "upload"
    assert "--input-dir" in argv
    assert "/tmp/x" in argv
    assert "/dev/cu.usbmodem01" in argv


def test_upload_debug_includes_board_options():
    argv = _upload_argv("/dev/cu.x", "esp32:esp32:esp32s3", True, "/tmp/x", ".")
    assert any("CDCOnBoot=cdc" in a for a in argv)


def test_cli_returns_str_or_none():
    from flashlib.build import _cli
    result = _cli()
    assert result is None or isinstance(result, str)
    if result:
        import os
        assert os.path.isfile(result) and os.access(result, os.X_OK)