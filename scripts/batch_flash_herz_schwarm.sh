#!/usr/bin/env bash
# Batch-Flashen aller angeschlossenen ESP32-S3-Boards (Herz_Schwarm_CCC_V).
# Protokolliert Firmware-String, Zeitpunkt, Port, Ergebnis und MAC in CSV + Markdown.
#
# Voraussetzungen: arduino-cli, esptool.py (z. B. Homebrew: brew install arduino-cli esptool)
#
# Nutzung:
#   ./scripts/batch_flash_herz_schwarm.sh
#   ./scripts/batch_flash_herz_schwarm.sh --ports /dev/cu.usbmodem1101 /dev/cu.usbmodem1102
#   ./scripts/batch_flash_herz_schwarm.sh --all-usb          # heuristisch: /dev/cu.usb* (kein Board-Erkennung nötig)
#   ./scripts/batch_flash_herz_schwarm.sh --debug            # CDC + Serial-Debug (siehe README)
#   ./scripts/batch_flash_herz_schwarm.sh --no-compile

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKETCH="Herz_Schwarm_CCC_V.ino"
INO="${REPO_ROOT}/${SKETCH}"
FQBN="esp32:esp32:esp32s3"
BUILD_DIR="${REPO_ROOT}/build_batch"
LOG_CSV="${REPO_ROOT}/firmware_update_log.csv"
LOG_MD="${REPO_ROOT}/firmware_update_log.md"

USE_DEBUG=0
DO_COMPILE=1
EXPLICIT_PORTS=()
ALL_USB=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) USE_DEBUG=1; shift ;;
    --no-compile) DO_COMPILE=0; shift ;;
    --all-usb) ALL_USB=1; shift ;;
    --ports) shift; while [[ $# -gt 0 && "$1" != --* ]]; do EXPLICIT_PORTS+=("$1"); shift; done ;;
    -h|--help)
      cat << 'HELP'
Batch-Flashen: arduino-cli + esptool (MAC). Voraussetzungen: arduino-cli, esptool.

  ./scripts/batch_flash_herz_schwarm.sh
  ./scripts/batch_flash_herz_schwarm.sh --ports /dev/cu.usbmodem1101 /dev/cu.usbmodem1102
  ./scripts/batch_flash_herz_schwarm.sh --all-usb
  ./scripts/batch_flash_herz_schwarm.sh --debug
  ./scripts/batch_flash_herz_schwarm.sh --no-compile

Protokoll: firmware_update_log.csv, firmware_update_log.md (Repo-Wurzel).
HELP
      exit 0
      ;;
    *) echo "Unbekannte Option: $1" >&2; exit 1 ;;
  esac
done

ESPTOOL="${ESPTOOL:-$(command -v esptool.py 2>/dev/null || true)}"
[[ -n "${ESPTOOL}" ]] || ESPTOOL="$(command -v esptool 2>/dev/null || true)"
if [[ -z "${ESPTOOL}" ]]; then
  echo "Fehler: esptool nicht gefunden. Bitte esptool installieren oder ESPTOOL=/pfad/zu/esptool.py setzen." >&2
  exit 1
fi

read_ino_define() {
  local key="$1"
  awk -F'[[:space:]]+' "/^#define[[:space:]]+${key}[[:space:]]+/ {print \$3; exit}" "$INO" | tr -d '\r'
}

FWMAJ="$(read_ino_define FW_VERSION_MAJOR)"
FWMIN="$(read_ino_define FW_VERSION_MINOR)"
FWPAT="$(read_ino_define FW_VERSION_PATCH)"
FWDG="$(read_ino_define FW_DEBUG_BUILD)"
if [[ -z "${FWMAJ}" || -z "${FWMIN}" || -z "${FWPAT}" || -z "${FWDG}" ]]; then
  echo "Fehler: Konnte FW_*-Defines in ${SKETCH} nicht lesen." >&2
  exit 1
fi

if (( USE_DEBUG )); then
  FIRMWARE_STR="${FWMAJ}.${FWMIN}.$(printf '%02d' "$((10#${FWDG}))")+debug"
  BOARD_OPT=(--board-options CDCOnBoot=cdc)
  EXTRA_FLAGS=(--build-property "compiler.cpp.extra_flags=-DENABLE_SERIAL_DEBUG=1")
else
  FIRMWARE_STR="${FWMAJ}.${FWMIN}.${FWPAT}"
  BOARD_OPT=()
  EXTRA_FLAGS=()
fi

collect_ports_arduino() {
  python3 - <<'PY'
import json, subprocess, sys
out = subprocess.check_output(
    ["arduino-cli", "board", "list", "--format", "json"],
    text=True,
)
data = json.loads(out)
ports = []
for item in data.get("detected_ports", []):
    p = (item.get("port") or {}).get("address")
    if not p:
        continue
    boards = item.get("matching_boards") or []
    for b in boards:
        fq = (b.get("fqbn") or "")
        # S3 oft als esp32s3; manche Treiber nennen nur esp32_family (z. B. Waveshare)
        if fq == "esp32:esp32:esp32s3" or fq.endswith(":esp32s3"):
            ports.append(p)
            break
        if fq == "esp32:esp32:esp32_family":
            ports.append(p)
            break
for u in sorted(set(ports)):
    print(u)
PY
}

# Fallback: sichtbare USB-ACM/-serial-Geräte (ohne bekannte Pseudo-Ports)
collect_ports_all_usb() {
  (
    shopt -s nullglob
    local dev path
    for path in /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.usb* /dev/cu.wchusbserial* /dev/cu.SLAB*; do
      [[ -e "$path" ]] || continue
      dev="${path#/dev/cu.}"
      case "$dev" in
        Bluetooth-Incoming-Port|debug-console|wlan-debug) continue ;;
      esac
      case "$dev" in
        usb*|SLAB*|wch*) printf '%s\n' "$path" ;;
      esac
    done | sort -u
  )
}

read_mac() {
  local port="$1"
  local out
  if ! out="$("$ESPTOOL" --chip esp32s3 --port "$port" read_mac 2>&1)"; then
    echo "MAC-Read fehlgeschlagen: $out" >&2
    echo ""
    return 1
  fi
  if echo "$out" | grep -qiE "(MAC|Base MAC): *"; then
    echo "$out" | grep -iE "(MAC|Base MAC):" | head -1 | sed -E 's/.*(MAC|Base MAC): *([0-9a-fA-F:]{17}).*/\2/' | tr '[:upper:]' '[:lower:]'
  else
    echo "MAC: nicht in Ausgabe" >&2
    echo "$out" >&2
    echo ""
  fi
}

append_logs() {
  local ts="$1" firmware="$2" port="$3" result="$4" mac="${5:-}"
  local need_header=0
  if [[ ! -f "${LOG_CSV}" ]]; then
    need_header=1
  fi
  if (( need_header )); then
    printf '%s\n' "timestamp;firmware;port;result;mac" >> "${LOG_CSV}"
  fi
  # Semikolon: Excel (DE) freundlich; in Feldern keine Semikolons
  printf '%s\n' "${ts};${firmware};${port};${result};${mac}" >> "${LOG_CSV}"

  if [[ ! -f "${LOG_MD}" ]]; then
    cat >> "${LOG_MD}" << 'HDR'
# Herz-Schwarm: Firmware-Update-Protokoll

Automatisch erzeugt von `scripts/batch_flash_herz_schwarm.sh`. Angehängte Zeilen pro Gerät pro Lauf.

| Zeitpunkt (lokal) | Firmware | serieller Port | Ergebnis | MAC (Chip) |
| --- | --- | --- | --- | --- |
HDR
  fi
  printf '| %s | %s | `%s` | %s | %s |\n' \
    "$ts" "$firmware" "$port" "$result" "${mac:-—}" >> "${LOG_MD}"
}

# --- Portliste ---
if ((${#EXPLICIT_PORTS[@]})); then
  PORTS=("${EXPLICIT_PORTS[@]}")
elif (( ALL_USB )); then
  PORTS=()
  while IFS= read -r _p; do [[ -n "${_p}" ]] && PORTS+=("${_p}"); done < <(collect_ports_all_usb)
else
  PORTS=()
  while IFS= read -r _p; do [[ -n "${_p}" ]] && PORTS+=("${_p}"); done < <(collect_ports_arduino)
fi

if ((${#PORTS[@]} == 0)); then
  echo "Keine seriellen Ports gefunden. Boards per USB verbinden oder explizit:" >&2
  echo "  $0 --ports /dev/cu.usbmodemXXXX ..." >&2
  echo "Oder ohne Board-Erkennung: $0 --all-usb" >&2
  exit 1
fi

echo "Firmware-Build: ${FIRMWARE_STR}"
echo "Gefundene Ports (${#PORTS[@]}): ${PORTS[*]}"
echo

if (( DO_COMPILE )); then
  echo "Kompilieren in ${BUILD_DIR} …"
  # shellcheck disable=SC2086
  arduino-cli compile --fqbn "$FQBN" "${BOARD_OPT[@]}" "${EXTRA_FLAGS[@]}" --build-path "$BUILD_DIR" "$REPO_ROOT"
  echo
else
  if [[ ! -d "${BUILD_DIR}" ]]; then
    echo "Fehler: ${BUILD_DIR} fehlt — bitte zuerst ohne --no-compile bauen." >&2
    exit 1
  fi
fi

for port in "${PORTS[@]}"; do
  if [[ ! -e "$port" ]]; then
    echo "Port existiert nicht (übersprungen): $port" >&2
    ts_now="$(date '+%Y-%m-%d %H:%M:%S %z')"
    append_logs "$ts_now" "$FIRMWARE_STR" "$port" "skip_no_device" ""
    continue
  fi
  echo ">>> Upload: $port"
  if ! arduino-cli upload -p "$port" --fqbn "$FQBN" "${BOARD_OPT[@]}" --input-dir "$BUILD_DIR" "$REPO_ROOT"; then
    ts_now="$(date '+%Y-%m-%d %H:%M:%S %z')"
    append_logs "$ts_now" "$FIRMWARE_STR" "$port" "upload_failed" ""
    echo "Upload fehlgeschlagen: $port" >&2
    continue
  fi
  echo "Kurz warten, dann MAC lesen …"
  sleep 1.5
  mac_read="$(read_mac "$port" || true)"
  ts_now="$(date '+%Y-%m-%d %H:%M:%S %z')"
  if [[ -n "${mac_read}" ]]; then
    append_logs "$ts_now" "$FIRMWARE_STR" "$port" "ok" "$mac_read"
    echo "OK $port → MAC $mac_read"
  else
    append_logs "$ts_now" "$FIRMWARE_STR" "$port" "ok_mac_unread" ""
    echo "Hinweis: Flash ok, MAC konnte nicht gelesen werden: $port" >&2
  fi
  echo
done

echo "Fertig. Protokoll: ${LOG_CSV} und ${LOG_MD}"
