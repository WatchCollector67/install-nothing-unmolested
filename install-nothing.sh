#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="install-nothing"
readonly APP_VERSION="1.0.0"

usage() {
  cat <<USAGE
$APP_NAME v$APP_VERSION

A dramatic installer that carefully installs absolutely nothing.

Usage:
  ./install-nothing.sh [--fast] [--seed N] [--quiet]
  ./install-nothing.sh --help

Options:
  --fast       Reduce wait times between steps.
  --seed N     Seed the random number generator for reproducible output.
  --quiet      Print only critical milestones.
  -h, --help   Show this message.
USAGE
}

FAST_MODE=0
QUIET_MODE=0
SEED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast)
      FAST_MODE=1
      shift
      ;;
    --seed)
      [[ $# -ge 2 ]] || { echo "error: --seed requires a value" >&2; exit 1; }
      SEED="$2"
      shift 2
      ;;
    --quiet)
      QUIET_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$SEED" ]]; then
  RANDOM=$SEED
fi

announce() {
  [[ "$QUIET_MODE" -eq 1 ]] && return 0
  printf '%s\n' "$*"
}

sleep_for() {
  local unit_ms="$1"
  if [[ "$FAST_MODE" -eq 1 ]]; then
    return 0
  fi
  # shellcheck disable=SC2059
  printf -v _seconds '0.%03d' "$unit_ms"
  sleep "$_seconds"
}

spin_step() {
  local label="$1"
  local loops="$2"
  local chars='|/-\\'
  local i frame

  printf '%s ' "$label"
  for ((i=0; i<loops; i++)); do
    frame="${chars:i%4:1}"
    printf '\r%s %s' "$label" "$frame"
    sleep_for $((30 + RANDOM % 90))
  done
  printf '\r%s done\n' "$label"
}

random_phrase() {
  local phrases=(
    "Calibrating vacuum tubes"
    "Indexing imaginary packages"
    "Resolving philosophical dependencies"
    "Compiling quantum placeholders"
    "Fetching bytes from /dev/null"
    "Negotiating with cosmic package registry"
    "Optimizing empty folders"
    "Verifying checksum of nothingness"
  )
  printf '%s' "${phrases[RANDOM % ${#phrases[@]}]}"
}

print_header() {
  cat <<'HEADER'
===========================================
       INSTALL NOTHING (BASH EDITION)
===========================================
HEADER
}

main() {
  print_header
  announce "Starting installation workflow..."

  local step_count=7
  local step
  for ((step=1; step<=step_count; step++)); do
    spin_step "[$step/$step_count] $(random_phrase)" $((8 + RANDOM % 8))
  done

  echo
  echo "✔ Successfully installed nothing."
  echo "✔ Disk usage impact: 0 bytes."
  echo "✔ Regret level: moderate."

  announce
  announce "Tip: Run again with --seed for deterministic absurdity."
}

main
