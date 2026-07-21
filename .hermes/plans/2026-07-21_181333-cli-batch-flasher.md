# CLI-Pseudo-GUI Batch-Flasher — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Interaktives Terminal-Tool (TUI) zum Flashen mehrerer ESP32-S3-Badges, portabel für macOS (primär) und Linux (sekundär), Windows als optionaler späterer Schritt.

**Architecture:** Wrapper-Script in Python 3 (stdlib only + `pyserial` für Port-Erkennung) — bewusst keine TUI-Library wie `prompt_toolkit`/`textual`, um Dependency-Footprint minimal zu halten. Pseudo-GUI via ANSI-Escapesequenzen, Listen-Auswahl über nummerierte Eingabe. Re-Use der Logik aus `scripts/batch_flash_herz_schwarm.sh` (Port-Discovery, Compile, Upload, MAC-Read) als ausführbares Backbone.

**Tech Stack:** Python 3.10+ (macOS hat 3.9+, Linux meist 3.8+), `pyserial` (für `list_ports`), `arduino-cli` (extern), `esptool.py` (extern). Build-Verzeichnis `build_batch_gui/`. Logs nach `firmware_update_log.csv` + `.md` (gleiche Struktur wie heute, neuer Logger).

---

## Voraussetzungen / Annahmen

- macOS als primäre Plattform (GalifreyM1, arm64)
- Linux x86_64 als sekundäre Plattform (gleicher Code-Pfad)
- Windows: explizit OUT OF SCOPE für v1.0 — Plan dokumentiert nur den Pfad, kein Code
- `arduino-cli` und `esptool.py` sind bereits vorhanden (Pfad-Logik aus `batch_flash_herz_schwarm.sh` übernehmen)
- Bestehende Logik bleibt **unverändert** — der neue Flasher ruft das bestehende Skript mit `--ports` auf, oder wir extrahieren die Build-Funktionen in ein Python-Modul, das beide nutzen

**Entscheidung:** Variante B — Extract & Share. Wir extrahieren die Build-/Upload-Logik in eine **gemeinsame Python-Library** `scripts/flashlib/` mit:
- `ports.py` (Port-Discovery: arduino-cli, /dev/cu.*, /dev/ttyUSB*, Filter ESP32-S3)
- `build.py` (compile + upload Wrapper um arduino-cli)
- `mac.py` (MAC-Read via esptool)
- `log.py` (CSV + MD Logger, gleiches Format wie `batch_flash_herz_schwarm.sh`)

Das bestehende Bash-Skript ruft am Ende `python3 -m flashlib.cli --ports …` auf (oder bleibt parallel bestehen). Das neue TUI nutzt `flashlib` direkt.

---

## Phasen

### Phase 0: Spike (5 min) — Designentscheidung bestätigen
Vor dem ersten Task kurz validieren, dass `pyserial` auf macOS ohne weitere Abhängigkeiten installierbar ist und ANSI-Escapes im Terminal von VSCode/iTerm/Ghostty funktionieren.

### Phase 1: Foundation — `flashlib` Library (4-5 Tasks)
Gemeinsame Logik in Python, von Bash und TUI genutzt.

### Phase 2: CLI Pseudo-GUI (4-5 Tasks)
Interaktives Menü mit ANSI-Frames, Port-Auswahl, Build-Optionen, Live-Progress.

### Phase 3: Polish (2-3 Tasks)
Fehlerbehandlung, README, Version-Bump, Tag.

---

## Task 1: Spike — pyserial + ANSI verifizieren

**Objective:** Sicherstellen, dass die Dependency-Wahl funktioniert.

**Files:**
- Touch: `scripts/flashlib/__init__.py` (leer)

**Step 1:** `pip3 install --user pyserial` ausführen, mit User-Bestätigung dass es klappt.

**Step 2:** Kurzes Test-Script `scripts/flashlib/_spike_ansi.py`:
```python
print("\033[1;36m┌── Test ──┐\033[0m\n\033[1;32m✓\033[0m ANSI OK\n\033[1;33m[1]\033[0m Menüpunkt")
```
Visuell prüfen: Box, Farben, nummerierte Items rendern.

**Step 3:** `python3 -c "import serial.tools.list_ports; print(len(serial.tools.list_ports.comports()))"` — sollte eine Zahl > 0 oder 0 sein, ohne Fehler.

**Step 4:** Spike-Script löschen.

**Verify:** OK, wenn pyserial installierbar und ANSI rendert.

---

## Task 2: `flashlib/ports.py` — Port-Discovery portabel

**Objective:** Funktion `discover_ports(include_all_usb: bool = False) -> list[str]` liefert ESP32-S3-Ports auf macOS und Linux identisch.

**Files:**
- Create: `scripts/flashlib/ports.py`
- Test: `scripts/flashlib/tests/test_ports.py`

**Step 1: Test schreiben** (TDD)
```python
def test_discover_returns_list():
    from flashlib.ports import discover_ports
    assert isinstance(discover_ports(), list)
def test_filter_matches_esp32s3():
    from flashlib.ports import _matches_esp32s3
    assert _matches_esp32s3("esp32:esp32:esp32s3")
    assert _matches_esp32s3("esp32:esp32:esp32_family")
    assert not _matches_esp32s3("esp32:esp32:esp32")
def test_dev_cu_glob_darwin():
    import sys
    from flashlib.ports import _dev_cu_globs
    if sys.platform == "darwin":
        globs = _dev_cu_globs()
        assert any("usbmodem" in g for g in globs)
    elif sys.platform.startswith("linux"):
        globs = _dev_cu_globs()
        assert any("ttyUSB" in g for g in globs)
```

**Step 2: Implementierung**
- `discover_ports()` versucht zuerst `arduino-cli board list --format json` (gleiche Logik wie Bash), filtert via `_matches_esp32s3`.
- Fallback (wenn `arduino-cli` fehlt ODER `--all-usb`): Glob über `_dev_cu_globs()`.
- `_dev_cu_globs()` gibt je nach `sys.platform` zurück:
  - `darwin`: `["/dev/cu.usbmodem*", "/dev/cu.usbserial*", "/dev/cu.usb*", "/dev/cu.wchusbserial*", "/dev/cu.SLAB*"]`
  - `linux`: `["/dev/ttyUSB*", "/dev/ttyACM*"]`
  - andere: `[]`

**Step 3: Tests laufen lassen**
Run: `cd scripts && python3 -m pytest flashlib/tests/ -v`
Expected: 3 passed.

**Step 4: Commit**
```bash
git add scripts/flashlib/
git commit -m "feat(flashlib): portable port discovery (darwin + linux)"
```

---

## Task 3: `flashlib/mac.py` — MAC-Read via esptool

**Objective:** `read_mac(port: str) -> str | None` ruft esptool auf, parst die Ausgabe.

**Files:**
- Create: `scripts/flashlib/mac.py`
- Test: `scripts/flashlib/tests/test_mac.py`

**Step 1: Test schreiben**
```python
def test_parse_mac_valid():
    from flashlib.mac import _parse_mac
    out = "MAC: aa:bb:cc:dd:ee:ff"
    assert _parse_mac(out) == "aa:bb:cc:dd:ee:ff"
def test_parse_mac_base():
    from flashlib.mac import _parse_mac
    out = "Base MAC: AA:BB:CC:11:22:33"
    assert _parse_mac(out) == "aa:bb:cc:11:22:33"
def test_parse_mac_none():
    from flashlib.mac import _parse_mac
    assert _parse_mac("no mac here") is None
```

**Step 2: Implementierung**
- `_parse_mac(text: str) -> str | None` sucht per Regex `r'(?:Base )?MAC:\s*([0-9a-fA-F:]{17})'`, lowercased.
- `read_mac(port, esptool_path=None)` findet esptool (env `ESPTOOL`, sonst `which esptool.py`/`which esptool`), ruft `subprocess.run([esptool, "--chip", "esp32s3", "--port", port, "read_mac"], capture_output=True, text=True, timeout=10)`, parst stdout.

**Step 3: Tests laufen**
Run: `cd scripts && python3 -m pytest flashlib/tests/test_mac.py -v`
Expected: 3 passed.

**Step 4: Commit**
```bash
git add scripts/flashlib/mac.py scripts/flashlib/tests/test_mac.py
git commit -m "feat(flashlib): esptool MAC-read with parse"
```

---

## Task 4: `flashlib/build.py` — Compile + Upload

**Objective:** `compile(fqbn, debug: bool, build_path) -> None` und `upload(port, fqbn, debug: bool, build_path, sketch_dir) -> bool` wrappen arduino-cli.

**Files:**
- Create: `scripts/flashlib/build.py`
- Test: `scripts/flashlib/tests/test_build.py` (nur Argumente, keine echten Builds)

**Step 1: Test schreiben**
```python
def test_compile_cmd_no_debug():
    from flashlib.build import _compile_argv
    argv = _compile_argv("esp32:esp32:esp32s3", debug=False, build_path="/tmp/x", sketch_dir=".")
    assert "--build-property" not in argv
    assert "esp32:esp32:esp32s3" in argv
def test_compile_cmd_debug():
    from flashlib.build import _compile_argv
    argv = _compile_argv("esp32:esp32:esp32s3", debug=True, build_path="/tmp/x", sketch_dir=".")
    assert any("ENABLE_SERIAL_DEBUG=1" in a for a in argv)
    assert any("CDCOnBoot=cdc" in a for a in argv)
def test_upload_uses_input_dir():
    from flashlib.build import _upload_argv
    argv = _upload_argv("/dev/cu.usbmodem01", "esp32:esp32:esp32s3", False, "/tmp/x", ".")
    assert "--input-dir" in argv
    assert "/tmp/x" in argv
```

**Step 2: Implementierung**
- `_compile_argv(fqbn, debug, build_path, sketch_dir) -> list[str]` — exakt die Flags aus `batch_flash_herz_schwarm.sh:198`.
- `_upload_argv(port, fqbn, debug, build_path, sketch_dir) -> list[str]` — exakt die Flags aus `batch_flash_herz_schwarm.sh:215`.
- `compile(...)` → `subprocess.run(arduino-cli + _compile_argv(...))`, returncode prüfen.
- `upload(...)` → `subprocess.run(...)`, returnt `True` bei rc=0.

**Step 3: Tests laufen**
Run: `cd scripts && python3 -m pytest flashlib/tests/test_build.py -v`
Expected: 3 passed.

**Step 4: Commit**
```bash
git add scripts/flashlib/build.py scripts/flashlib/tests/test_build.py
git commit -m "feat(flashlib): arduino-cli compile+upload wrappers"
```

---

## Task 5: `flashlib/log.py` — CSV + MD Logger

**Objective:** `Log.append(timestamp, firmware, port, result, mac)` schreibt Zeilen in beide Formate (gleiche Struktur wie Bash).

**Files:**
- Create: `scripts/flashlib/log.py`
- Test: `scripts/flashlib/tests/test_log.py`

**Step 1: Test schreiben**
```python
import tempfile, os
def test_csv_header_created(tmp_path):
    from flashlib.log import Log
    log = Log(csv_path=tmp_path/"l.csv", md_path=tmp_path/"l.md")
    log.append("2026-07-21 18:00:00 +0200", "1.1.0", "/dev/cu.x", "ok", "aa:bb:cc:dd:ee:ff")
    content = (tmp_path/"l.csv").read_text()
    assert content.startswith("timestamp;firmware;port;result;mac")
    assert "2026-07-21 18:00:00 +0200;1.1.0;/dev/cu.x;ok;aa:bb:cc:dd:ee:ff" in content
def test_md_header_created(tmp_path):
    from flashlib.log import Log
    log = Log(csv_path=tmp_path/"l.csv", md_path=tmp_path/"l.md")
    log.append("2026-07-21 18:00:00 +0200", "1.1.0", "/dev/cu.x", "ok", "")
    content = (tmp_path/"l.md").read_text()
    assert "Firmware-Update-Protokoll" in content
    assert "2026-07-21 18:00:00 +0200" in content
```

**Step 2: Implementierung**
- `Log(csv_path, md_path)` — Pfade als Parameter, keine Hardcodes.
- `append(...)` schreibt CSV-Zeile (immer mit Header-Check) und MD-Zeile (mit Header wenn Datei neu).
- Format exakt wie `batch_flash_herz_schwarm.sh:append_logs()` Zeilen 154-170.

**Step 3: Tests laufen**
Run: `cd scripts && python3 -m pytest flashlib/tests/test_log.py -v`
Expected: 2 passed.

**Step 4: Commit**
```bash
git add scripts/flashlib/log.py scripts/flashlib/tests/test_log.py
git commit -m "feat(flashlib): csv+md logger"
```

---

## Task 6: `flashlib/firmware.py` — Version aus .ino lesen

**Objective:** `read_firmware_version(ino_path) -> tuple[int,int,int,int]` parst `FW_VERSION_MAJOR/MINOR/PATCH` und `FW_DEBUG_BUILD`.

**Files:**
- Create: `scripts/flashlib/firmware.py`
- Test: `scripts/flashlib/tests/test_firmware.py`

**Step 1: Test schreiben**
```python
def test_parse_fw_defines(tmp_path):
    ino = tmp_path/"x.ino"
    ino.write_text("""
#define FW_VERSION_MAJOR 1
#define FW_VERSION_MINOR 2
#define FW_VERSION_PATCH 3
#define FW_DEBUG_BUILD 5
""")
    from flashlib.firmware import read_firmware_version
    assert read_firmware_version(str(ino)) == (1, 2, 3, 5)
def test_firmware_string_release():
    from flashlib.firmware import firmware_string
    assert firmware_string((1, 2, 3, 0), debug=False) == "1.2.3"
def test_firmware_string_debug():
    from flashlib.firmware import firmware_string
    assert firmware_string((1, 2, 3, 5), debug=True) == "1.2.05+debug"
```

**Step 2: Implementierung**
- `read_firmware_version(ino_path)`: Regex `r'#define\s+FW_VERSION_(MAJOR|MINOR|PATCH|DEBUG_BUILD)\s+(\d+)'`, alle vier extrahieren.
- `firmware_string(version_tuple, debug) -> str`:
  - release: `f"{m}.{n}.{p}"`
  - debug: `f"{m}.{n}.{p:02d}+debug"` (nimmt MAJOR.MINOR + DEBUG_BUILD als %02d)

**Step 3: Tests laufen**
Run: `cd scripts && python3 -m pytest flashlib/tests/test_firmware.py -v`
Expected: 3 passed.

**Step 4: Commit**
```bash
git add scripts/flashlib/firmware.py scripts/flashlib/tests/test_firmware.py
git commit -m "feat(flashlib): parse FW_VERSION_* from ino"
```

---

## Task 7: TUI — `scripts/flash_gui.py` (Hauptprogramm)

**Objective:** Interaktives Menü mit ANSI-Frames. Menüpunkte: 1) Ports scannen, 2) Build (Debug/Release), 3) Flashen, 4) Log anzeigen, 5) Beenden.

**Files:**
- Create: `scripts/flash_gui.py`

**Step 1: Hilfsfunktionen definieren**
```python
def clear(): print("\033[2J\033[H", end="")
def box(title: str, lines: list[str], color: str = "1;36"):
    width = max(len(title) + 4, max(len(l) for l in lines) + 4, 40)
    top = f"\033[{color}m┌─[\033[0m {title} \033[{color}m]" + "─" * (width - len(title) - 5) + "┐\033[0m"
    bot = f"\033[{color}m└" + "─" * (width - 2) + "┘\033[0m"
    body = "\n".join(f"\033[{color}m│\033[0m {l.ljust(width - 4)} \033[{color}m│\033[0m" for l in lines)
    return f"{top}\n{body}\n{bot}"
def menu(title: str, items: list[tuple[str, str]]) -> int:
    # items: [(key, label), ...]. Returns 0-based index.
    print(box(title, [f"\033[1;33m[{k}]\033[0m {v}" for k, v in items]))
    choice = input("\n\033[1;36m›\033[0m Auswahl: ").strip()
    for i, (k, _) in enumerate(items):
        if choice == k:
            return i
    return -1
```

**Step 2: Hauptschleife**
```python
def main():
    state = {"ports": [], "fw_version": None, "debug": False, "build_path": None}
    while True:
        clear()
        print("\033[1;35m╔══════════════════════════════════════╗\033[0m")
        print("\033[1;35m║   Herz-Schwarm Batch-Flasher  v0.1   ║\033[0m")
        print("\033[1;35m╚══════════════════════════════════════╝\033[0m")
        # Effekt-Steuerung (modes 1-8) ist NICHT Teil dieses Tools —
        # läuft über MQTT (Basisstation) oder Web-UI Port 80.
        choice = menu("Hauptmenü", [
            ("1", "Ports scannen"),
            ("2", f"Build-Modus: {'Debug' if state['debug'] else 'Release'} (toggle)"),
            ("3", "Firmware kompilieren"),
            ("4", f"Flashen ({len(state['ports'])} Port(s))"),
            ("5", "Log anzeigen"),
            ("q", "Beenden"),
        ])
        if choice == 0: action_scan(state)
        elif choice == 1: state["debug"] = not state["debug"]
        elif choice == 2: action_build(state)
        elif choice == 3: action_flash(state)
        elif choice == 4: action_log(state)
        elif choice == 5 or choice == -1 and input_choice == "q": break
```

**Step 3: Action-Funktionen**
- `action_scan(state)`: ruft `discover_ports()`, zeigt Box mit Liste, "Enter zum Übernehmen, Zahl zum Filtern". Multi-Select per Komma-getrennter Eingabe.
- `action_build(state)`: ruft `compile(...)` mit aktuellem `state["debug"]`, zeigt Live-Output in scrollender Box (einfach: subprocess mit Popen, zeilenweise printen).
- `action_flash(state)`: pro Port `upload(...)` + `read_mac(...)` + `Log.append(...)`, mit Progress `[2/5] /dev/cu.usbmodem01 …`.
- `action_log(state)`: `tail -20 firmware_update_log.md` einlesen und in Box anzeigen.

**Step 4: Manuelle Verifikation**
Run: `python3 scripts/flash_gui.py`
Expected: Menü erscheint, Navigation funktioniert, "Beenden" beendet sauber.

**Step 5: Commit**
```bash
git add scripts/flash_gui.py
git commit -m "feat(flash-gui): TUI batch-flasher skeleton"
```

---

## Task 8: Integration — Bash-Skript nutzt flashlib optional

**Objective:** `batch_flash_herz_schwarm.sh` ruft `python3 scripts/flash_gui.py` auf, wenn mit `--gui` oder ohne Args und TTY erkannt.

**Files:**
- Modify: `scripts/batch_flash_herz_schwarm.sh`

**Step 1:** Vor der Port-Discovery-Sektion hinzufügen:
```bash
if [[ -z "${NO_GUI:-}" ]] && [[ -t 1 ]] && [[ "${1:-}" != "--no-gui" ]]; then
  if command -v python3 >/dev/null 2>&1 && [[ -f "${REPO_ROOT}/scripts/flash_gui.py" ]]; then
    exec python3 "${REPO_ROOT}/scripts/flash_gui.py" "$@"
  fi
fi
```

**Step 2:** `--no-gui`-Flag in Arg-Parser ergänzen.

**Step 3:** Verifizieren: `./scripts/batch_flash_herz_schwarm.sh --help` zeigt weiterhin Hilfe, ohne TTY-Umleitung.

**Step 4: Commit**
```bash
git add scripts/batch_flash_herz_schwarm.sh
git commit -m "feat(batch-flash): launch TUI by default if TTY present"
```

---

## Task 9: README — Abschnitt "CLI-Flasher" hinzufügen

**Objective:** Kurzanleitung im README.

**Files:**
- Modify: `README.md`

**Step 1:** Nach dem bestehenden `## 🛠 Setup & Configuration`-Block einen neuen Abschnitt einfügen:
```markdown
### CLI Pseudo-GUI (`scripts/flash_gui.py`)

Interaktives Flashen mehrerer Badges, portabel für macOS (primär) und Linux.

```bash
pip3 install --user pyserial   # macOS/Linux
python3 scripts/flash_gui.py
```

Menü: 1) Ports scannen, 2) Build-Modus, 3) Kompilieren, 4) Flashen, 5) Log.
Logs werden in `firmware_update_log.csv`/`.md` angehängt (gleiches Format wie `batch_flash_herz_schwarm.sh`).

Windows: nicht in v0.1 unterstützt (geplant für v0.2 — siehe `.hermes/plans/`).
```

**Step 2:** Im Englischen Pendant (Zeile ~30) analog ergänzen.

**Step 3: Commit**
```bash
git add README.md
git commit -m "docs: CLI-Pseudo-GUI section"
```

---

## Task 10: Tag v0.1.0 + Version-Bump

**Objective:** Release-Tag nach Abschluss.

**Files:**
- Modify: N/A
- Tag: `v0.1.0`

**Step 1:** `git tag -a v0.1.0 -m "feat: CLI Pseudo-GUI for batch-flasher"` setzen.

**Step 2:** Push: `git push origin main --tags`.

**Step 3:** In `scripts/flash_gui.py` Hardcode-Version `v0.1` → Variable `__version__ = "0.1.0"`, in `box(...)` Hauptmenü verwenden.

---

## Phase 4 (optional, später): Windows-Support

Nicht in diesem Plan. Wenn gewünscht, separates Plan-Dokument:
- `pyserial` installiert auf Windows out-of-the-box via `pip`
- Port-Glob: `COM3`, `COM4`, … (kein `/dev/`)
- ANSI: Windows 10+ aktiviert VT-Mode per `os.system('')` oder `ctypes.windll.kernel32.SetConsoleMode()`
- Shebang/Executable: `py` statt `python3`, `.bat`-Wrapper als Alternative
- Pfad-Separator: `pathlib.Path` nutzen, nicht `os.path.join`

Geschätzter Aufwand: 1-2 Stunden zusätzlich, separater PR.

---

## Risiken & Tradeoffs

| Risiko | Mitigation |
|--------|-----------|
| ANSI-Rendering in VSCode-SSH/Windows-Terminal | Fallback: `NO_COLOR=1` env-var, dann plain text ohne Escapes |
| pyserial auf macOS nicht installiert | Pre-Check im TUI mit klarer Fehlermeldung + Install-Hinweis |
| Build dauert lange (20s), TUI wirkt eingefroren | Live-Output in Box scrollen, nicht warten bis fertig |
| Race-Condition: zwei FLash-Sessions parallel | Lockfile `~/.herz-flasher.lock` mit PID-Check |
| Build-Path `build_batch_gui/` kollidiert mit `build_batch/` | Anderer Name gewählt |
| Bestehende Bash-Logik dupliciert | bewusst: Python re-implementiert, Bash-Skript bleibt als Fallback |

## Verifikation gesamt

Nach Task 10:
1. `cd scripts && python3 -m pytest flashlib/tests/ -v` → alle Tests grün
2. `python3 scripts/flash_gui.py` → Menü erscheint, Navigation OK
3. `./scripts/batch_flash_herz_schwarm.sh --no-gui` → Bash-Variante weiterhin funktional
4. `pip3 install --user pyserial` in README dokumentiert
5. **Kein Hardware-Test möglich** (kein ESP32 an Mac) — nur statische Verifikation

## Offene Fragen

- Soll der TUI auch `mode`-Wechsel (Effekte) für bereits geflashte Badges unterstützen? **NEIN** — Effekte laufen ausschließlich über MQTT (Basisstation) oder Web-UI (Basisstation). TUI ist nur für **Flash-Operationen** (Compile, Upload, MAC-Read, Log). Begründung: Effekt-Steuerung passiert in der `Herz_Schwarm_BaseStation.ino` (Web-UI Port 80, MQTT Subscribe) — der TUI-Flasher hat keinen ESP-NOW-Adapter, also wäre das ein anderes Tool.
- Soll `--parallel` Flashen (mehrere Boards gleichzeitig) in v0.1 oder v0.2? Plan vorsieht: sequentiell in v0.1
- Soll `firmware_update_log.{csv,md}` geteilt oder eine neue `firmware_update_log_gui.{csv,md}` angelegt werden? Plan vorsieht: gleiche Datei (anhängen) — keine Duplikation

---

**Saved at:** `.hermes/plans/2026-07-21_181333-cli-batch-flasher.md`
