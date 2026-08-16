#!/usr/bin/env bash
# Versionierungs-Helper fuer A.B.C.D-Schema.
#
#   A = MAJOR (nur auf speziellen Wunsch, Breaking Change)
#   B = MINOR (grosses Feature, z. B. 1.1.0 -> 1.2.0 = TUI)
#   C = PATCH (kleines Feature, Refactor)
#   D = BUILD (Git-Commit-Counter, automatisch)
#
# D wird in den Firmware-Code NICHT eingebaut (zu instabil), sondern
# nur als Git-Tag gefuehrt: v1.2.0.5 = 5 Commits seit 1.2.0.
#
# Das A.B.C.D-Schema gilt nur fuer die Badge-Firmware (Herz_Schwarm_CCC_V.ino)
# und treibt den repo-weiten vA.B.C.D-Git-Tag. Die anderen Module im Monorepo
# (Basisstation, Bridge, Nerves-App, flashlib) versionieren sich unabhaengig
# mit eigenem MAJOR.MINOR.PATCH -- siehe `all`/`tag`, die deren Stand als
# Snapshot mitfuehren. Details: README.md "Versionen aller Module".
#
# Nutzung:
#   scripts/version.sh current          # aktuelle A.B.C (Badge) aus dem .ino
#   scripts/version.sh all              # Versionen aller 5 Module
#   scripts/version.sh next-tag         # vorschlag fuer naechsten Tag
#   scripts/version.sh tag             # Tag setzen (annotiert, mit Modul-Snapshot)
#   scripts/version.sh since A.B.C.D   # Commits seit Tag

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKETCH="${REPO_ROOT}/Herz_Schwarm_CCC_V.ino"
BASESTATION_SKETCH="${REPO_ROOT}/Herz_Schwarm_BaseStation/Herz_Schwarm_BaseStation.ino"
BRIDGE_SKETCH="${REPO_ROOT}/herz_schwarm_nerves/firmware/esp32_bridge/esp32_bridge.ino"
NERVES_MIXEXS="${REPO_ROOT}/herz_schwarm_nerves/mix.exs"
FLASHLIB_INIT="${REPO_ROOT}/scripts/flashlib/__init__.py"

read_ino_define() {
  local file="$1" key="$2"
  awk -F'[[:space:]]+' "/^#define[[:space:]]+${key}[[:space:]]+/ {print \$3; exit}" "$file" 2>/dev/null | tr -d '\r'
}

read_ino_abc() {
  # A.B.C aus drei #define-Feldern eines .ino, "?" bei fehlender/unlesbarer Datei
  local file="$1" maj_key="$2" min_key="$3" pat_key="$4"
  local maj min pat
  maj=$(read_ino_define "$file" "$maj_key")
  min=$(read_ino_define "$file" "$min_key")
  pat=$(read_ino_define "$file" "$pat_key")
  if [[ -z "$maj" || -z "$min" || -z "$pat" ]]; then
    echo "?"
    return
  fi
  echo "${maj}.${min}.${pat}"
}

read_quoted_version() {
  # Erste Zeile "<prefix> [=] \"X.Y.Z\"" -- Elixir "@version \"...\"" hat kein
  # "=", Python "__version__ = \"...\"" schon, daher optionales "=".
  local file="$1" prefix="$2"
  local line
  line=$(grep -m1 -E "^[[:space:]]*${prefix}[[:space:]]*=?[[:space:]]*\"[0-9]+\.[0-9]+\.[0-9]+\"" "$file" 2>/dev/null) || true
  if [[ -z "$line" ]]; then
    echo "?"
    return
  fi
  echo "$line" | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'
}

current_abc() {
  local abc
  abc=$(read_ino_abc "$SKETCH" FW_VERSION_MAJOR FW_VERSION_MINOR FW_VERSION_PATCH)
  if [[ "$abc" == "?" ]]; then
    echo "FEHLER: Konnte FW_VERSION_*-Defines nicht aus Badge-.ino lesen." >&2
    exit 1
  fi
  echo "$abc"
}

basestation_abc() {
  read_ino_abc "$BASESTATION_SKETCH" BASESTATION_FW_MAJOR BASESTATION_FW_MINOR BASESTATION_FW_PATCH
}

bridge_abc() {
  read_ino_abc "$BRIDGE_SKETCH" BRIDGE_FW_MAJOR BRIDGE_FW_MINOR BRIDGE_FW_PATCH
}

nerves_version() {
  read_quoted_version "$NERVES_MIXEXS" "@version"
}

flashlib_version() {
  read_quoted_version "$FLASHLIB_INIT" "__version__"
}

all_versions() {
  echo "badge=$(current_abc)"
  echo "basestation=$(basestation_abc)"
  echo "bridge=$(bridge_abc)"
  echo "nerves=$(nerves_version)"
  echo "flashlib=$(flashlib_version)"
}

last_abc_tag() {
  # Letzter Tag in vA.B.C (ohne .D) auf HEAD
  local abc="$1"
  git tag --list "v${abc}.*" --sort=-version:refname | head -1
}

next_tag() {
  local abc="$1"
  local last
  last=$(last_abc_tag "$abc")
  if [[ -z "$last" ]]; then
    # Kein vA.B.C.*-Tag → D=0
    echo "v${abc}.0"
    return
  fi
  # D inkrementieren
  local d="${last##*.}"
  echo "v${abc}.$((d + 1))"
}

cmd_current() {
  current_abc
}

cmd_all() {
  all_versions
}

cmd_next_tag() {
  next_tag "$(current_abc)"
}

cmd_since() {
  local ref="$1"
  git log --oneline "${ref}..HEAD" | wc -l | tr -d ' '
}

cmd_tag() {
  local abc
  abc=$(current_abc)
  local tag
  tag=$(next_tag "$abc")
  echo "Setze Tag: $tag (A.B.C = $abc, D = Anzahl Commits seit v${abc}.0 bzw. letztem Tag)"

  local msg
  msg="Release ${tag} (Badge A.B.C = ${abc}, D = Git-Build)

Modul-Versionen zum Zeitpunkt dieses Tags:
$(all_versions | sed 's/^/  /')"

  git tag -a "$tag" -m "$msg"
  echo "OK. Push mit: git push origin $tag"
}

case "${1:-}" in
  current)    cmd_current ;;
  all)        cmd_all ;;
  next-tag)   cmd_next_tag ;;
  since)
    if [[ -z "${2:-}" ]]; then
      echo "Nutzen: scripts/version.sh since v1.2.0.0" >&2
      exit 1
    fi
    cmd_since "$2"
    ;;
  tag)        cmd_tag ;;
  -h|--help)
    cat <<'USAGE'
scripts/version.sh — A.B.C.D Versions-Helper (Badge) + Cross-Modul-Snapshot

Befehle:
  current       Aktuelle A.B.C der Badge-FW aus dem .ino auslesen
  all           Versionen aller 5 Module (Badge, Basisstation, Bridge, Nerves, flashlib)
  next-tag      Naechsten vA.B.C.D-Tag vorschlagen (D = Commits seit vA.B.C.0)
  since REF     Anzahl Commits seit REF
  tag           Annotierten Tag setzen (A.B.C aus Badge-.ino, D = auto-inkrement,
                Tag-Message enthaelt Snapshot aller 5 Modul-Versionen)

Beispiel:
  $ scripts/version.sh current
  1.2.0
  $ scripts/version.sh all
  badge=1.2.0
  basestation=0.1.7
  bridge=0.1.2
  nerves=0.1.1
  flashlib=0.1.0
  $ scripts/version.sh next-tag
  v1.2.0.5
  $ scripts/version.sh tag
  Setze Tag: v1.2.0.5 (A.B.C = 1.2.0, D = 5 Commits seit v1.2.0.0)
  OK.
USAGE
    ;;
  *)
    echo "Unbekannter Befehl: ${1:-}. Nutze: scripts/version.sh -h" >&2
    exit 1
    ;;
esac
