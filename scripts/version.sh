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
# Nutzung:
#   scripts/version.sh current          # aktuelle A.B.C aus dem .ino
#   scripts/version.sh next-tag         # vorschlag fuer naechsten Tag
#   scripts/version.sh tag             # Tag setzen (annotiert)
#   scripts/version.sh since A.B.C.D   # Commits seit Tag

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKETCH="${REPO_ROOT}/Herz_Schwarm_CCC_V.ino"

read_ino_define() {
  local key="$1"
  awk -F'[[:space:]]+' "/^#define[[:space:]]+${key}[[:space:]]+/ {print \$3; exit}" "$SKETCH" | tr -d '\r'
}

current_abc() {
  local maj min pat
  maj=$(read_ino_define FW_VERSION_MAJOR)
  min=$(read_ino_define FW_VERSION_MINOR)
  pat=$(read_ino_define FW_VERSION_PATCH)
  if [[ -z "$maj" || -z "$min" || -z "$pat" ]]; then
    echo "FEHLER: Konnte FW_VERSION_*-Defines nicht lesen." >&2
    exit 1
  fi
  echo "${maj}.${min}.${pat}"
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
  git tag -a "$tag" -m "Release $tag (A.B.C = $abc, D = Git-Build)"
  echo "OK. Push mit: git push origin $tag"
}

case "${1:-}" in
  current)    cmd_current ;;
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
scripts/version.sh — A.B.C.D Versions-Helper

Befehle:
  current       Aktuelle A.B.C aus dem .ino auslesen
  next-tag      Naechsten vA.B.C.D-Tag vorschlagen (D = Commits seit vA.B.C.0)
  since REF     Anzahl Commits seit REF
  tag           Annotierten Tag setzen (A.B.C aus .ino, D = auto-inkrement)

Beispiel:
  $ scripts/version.sh current
  1.2.0
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
