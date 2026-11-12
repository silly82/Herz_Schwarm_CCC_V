"""Terminal helpers for the TUI: ANSI setup, visible width, boxes."""

from __future__ import annotations

import os
import re
import shutil
import sys
from typing import List

_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def strip_ansi(text: str) -> str:
    return _ANSI_RE.sub("", text)


def visible_len(text: str) -> int:
    """Length as shown on screen (ANSI colour codes do not take up space)."""
    return len(strip_ansi(text))


def pad(text: str, width: int) -> str:
    """Left-justify to `width` visible columns."""
    return text + " " * max(0, width - visible_len(text))


def fit(text: str, width: int) -> str:
    """Pad to `width`; too long text loses its colours and is cut with an ellipsis."""
    if visible_len(text) <= width:
        return pad(text, width)
    plain = strip_ansi(text)
    return plain[: max(0, width - 1)] + "…"


def terminal_width(default: int = 80) -> int:
    return shutil.get_terminal_size((default, 24)).columns


def init_terminal() -> bool:
    """Prepare stdout; returns True if ANSI colours may be used.

    - UTF-8 output (Windows consoles default to a legacy code page, where the box
      characters would raise UnicodeEncodeError)
    - Windows: switch the console to VT mode so escape sequences are interpreted
    - colours off for NO_COLOR or when stdout is not a terminal
    """
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, ValueError, OSError):
        pass
    if os.environ.get("NO_COLOR") is not None or not sys.stdout.isatty():
        return False
    if os.name == "nt":
        return _enable_windows_vt()
    return True


def _enable_windows_vt() -> bool:
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
        handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        mode = ctypes.c_uint32()
        if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            # Kein Windows-Konsolenfenster (z. B. Git Bash/mintty): dort gilt TERM.
            return bool(os.environ.get("TERM"))
        return bool(kernel32.SetConsoleMode(handle, mode.value | 0x0004))
    except Exception:
        return False


def half_blocks(rows: List[str]) -> List[str]:
    """Pixel art from rows of 'X'/'.': two pixel rows per text line (▀ ▄ █), so pixels look square."""
    rows = list(rows) + ["" for _ in range(len(rows) % 2)]
    width = max((len(r) for r in rows), default=0)
    out = []
    for top, bottom in zip(rows[0::2], rows[1::2]):
        line = ""
        for x in range(width):
            upper = x < len(top) and top[x] != "."
            lower = x < len(bottom) and bottom[x] != "."
            line += "█" if upper and lower else "▀" if upper else "▄" if lower else " "
        out.append(line)
    return out


def beside(left: List[str], right: List[str], gap: int = 2) -> List[str]:
    """Put two blocks of lines next to each other (left block padded to equal width)."""
    width = max((visible_len(l) for l in left), default=0)
    height = max(len(left), len(right))
    left = left + [""] * (height - len(left))
    right = right + [""] * (height - len(right))
    return [(pad(l, width) + " " * gap + r).rstrip() for l, r in zip(left, right)]


def box(title: str, lines: List[str], paint=None, min_width: int = 60, max_width: int = 0) -> str:
    """Render a box. `paint(text)` colours the frame; content may carry its own colours.

    The box grows with its content up to the terminal width; longer lines are cut.
    """
    paint = paint or (lambda s: s)
    limit = max_width or max(40, terminal_width() - 1)
    need = max([visible_len(l) for l in lines] + [visible_len(title) + 4]) + 4
    width = min(max(min_width, need), limit)
    inner = width - 4
    title = fit(title, max(1, width - 8)).rstrip()
    top = paint("┌─[ " + title + " ]" + "─" * (width - visible_len(title) - 7) + "┐")
    bot = paint("└" + "─" * (width - 2) + "┘")
    body = [paint("│ ") + fit(l, inner) + paint(" │") for l in lines]
    return "\n".join([top, *body, bot])
