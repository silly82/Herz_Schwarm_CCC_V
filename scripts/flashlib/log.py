"""Append-only CSV + Markdown firmware-update logger.

Same format as `scripts/batch_flash_herz_schwarm.sh::append_logs`.
"""

from __future__ import annotations

from pathlib import Path
from typing import Union

PathLike = Union[str, Path]

_CSV_HEADER = "timestamp;firmware;port;result;mac"
_MD_HEADER = """# Herz-Schwarm: Firmware-Update-Protokoll

Automatisch erzeugt vom `flashlib`-Logger. Angehängte Zeilen pro Gerät pro Lauf.

| Zeitpunkt (lokal) | Firmware | serieller Port | Ergebnis | MAC (Chip) |
| --- | --- | --- | --- | --- |
"""


class Log:
    """Append-only logger for firmware update events."""

    def __init__(self, csv_path: PathLike, md_path: PathLike) -> None:
        self.csv_path = Path(csv_path)
        self.md_path = Path(md_path)

    def append(self, timestamp: str, firmware: str, port: str, result: str, mac: str = "") -> None:
        """Append one firmware-update entry to both CSV and MD files."""
        self._append_csv(timestamp, firmware, port, result, mac)
        self._append_md(timestamp, firmware, port, result, mac)

    def _append_csv(self, ts: str, fw: str, port: str, result: str, mac: str) -> None:
        new_file = not self.csv_path.exists()
        if new_file:
            self.csv_path.parent.mkdir(parents=True, exist_ok=True)
            self.csv_path.write_text(_CSV_HEADER + "\n")
        with self.csv_path.open("a") as f:
            f.write(f"{ts};{fw};{port};{result};{mac}\n")

    def _append_md(self, ts: str, fw: str, port: str, result: str, mac: str) -> None:
        new_file = not self.md_path.exists()
        if new_file:
            self.md_path.parent.mkdir(parents=True, exist_ok=True)
            self.md_path.write_text(_MD_HEADER)
        mac_disp = mac if mac else "—"
        with self.md_path.open("a") as f:
            f.write(f"| {ts} | {fw} | `{port}` | {result} | {mac_disp} |\n")

    def tail_md(self, lines: int = 20) -> str:
        """Return last N lines of the MD log (or whole file if shorter)."""
        if not self.md_path.exists():
            return ""
        text = self.md_path.read_text().splitlines()
        return "\n".join(text[-lines:])
