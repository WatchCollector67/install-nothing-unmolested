#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="install-nothing"
readonly APP_VERSION="2.0.0"

FAST_MODE=0
QUIET_MODE=0
SEED=""

usage() {
  cat <<USAGE
$APP_NAME v$APP_VERSION

Fake Debian-style installer that installs delightfully useless UNIX tools.
Nothing is actually installed.

Usage:
  ./install-nothing.sh [--fast] [--seed N] [--quiet]
  ./install-nothing.sh --help

Options:
  --fast       Reduce all animation delays.
  --seed N     Seed random output for deterministic runs.
  --quiet      Suppress most apt-like chatter.
  -h, --help   Show this message.
USAGE
}

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

say() {
  [[ "$QUIET_MODE" -eq 1 ]] && return 0
  printf '%s\n' "$*"
}

pause_ms() {
  local ms="$1"
  local seconds
  if [[ "$FAST_MODE" -eq 1 ]]; then
    return 0
  fi
  printf -v seconds '0.%03d' "$ms"
  sleep "$seconds"
}

progress_line() {
  local pct="$1"
  local current="$2"
  local total="$3"
  local rate="$4"
  local remaining="$5"
  local bar_width=28
  local filled=$((pct * bar_width / 100))
  local empty=$((bar_width - filled))
  local filled_bar
  local empty_bar

  printf -v filled_bar '%*s' "$filled" ''
  printf -v empty_bar '%*s' "$empty" ''
  filled_bar=${filled_bar// /#}
  empty_bar=${empty_bar// /.}

  printf '\r%3d%% [%s%s] %d/%d kB %s %s' \
    "$pct" "$filled_bar" "$empty_bar" "$current" "$total" "$rate" "$remaining"
}

animate_fetch() {
  local total="$1"
  local current=0
  local pct=0
  local step

  for step in 1 2 3 4 5 6 7 8 9 10; do
    current=$((total * step / 10))
    pct=$((step * 10))
    progress_line "$pct" "$current" "$total" "$((500 + RANDOM % 1900)) kB/s" "0s"
    pause_ms $((50 + RANDOM % 110))
  done
  printf '\n'
}

random_pkg_count() {
  printf '%d' "$((18 + RANDOM % 14))"
}

random_total_size() {
  printf '%d' "$((3200 + RANDOM % 9000))"
}

pkg_list=(
  sl
  cowsay
  fortune-mod
  cmatrix
  lolcat
  neofetch
  htop
  figlet
  toilet
  ninvaders
  asciiquarium
)

show_apt_preamble() {
  say "Reading package lists... Done"
  pause_ms 140
  say "Building dependency tree... Done"
  pause_ms 120
  say "Reading state information... Done"
  pause_ms 120

  local count
  count="$(random_pkg_count)"
  say "The following NEW packages will be installed:"
  say "  ${pkg_list[*]}"
  say "0 upgraded, ${#pkg_list[@]} newly installed, 0 to remove and ${count} not upgraded."
}

show_download_phase() {
  local total
  total="$(random_total_size)"
  say "Need to get ${total} kB of archives."
  say "After this operation, $((1200 + RANDOM % 9000)) kB of additional disk space will be used."
  say "Get:1 http://deb.debian.org/debian stable/main amd64 fun-packages all 1.0 [${total} kB]"
  animate_fetch "$total"
  say "Fetched ${total} kB in 0s ($((800 + RANDOM % 2500)) kB/s)"
}

show_unpack_phase() {
  local i pkg
  for i in "${!pkg_list[@]}"; do
    pkg="${pkg_list[$i]}"
    say "Selecting previously unselected package ${pkg}."
    pause_ms $((50 + RANDOM % 80))
    say "(Reading database ... $((42000 + i * 101 + RANDOM % 40)) files and directories currently installed.)"
    pause_ms $((40 + RANDOM % 60))
    say "Preparing to unpack .../${pkg}_${i}.deb ..."
    pause_ms $((35 + RANDOM % 50))
    say "Unpacking ${pkg} (1.0-${i}) ..."
    pause_ms $((45 + RANDOM % 70))
  done
}

show_setup_phase() {
  local pkg
  for pkg in "${pkg_list[@]}"; do
    say "Setting up ${pkg} (1.0-fake) ..."
    pause_ms $((45 + RANDOM % 70))
  done

  say "Processing triggers for man-db (2.11.2-2) ..."
  pause_ms 80
  say "Processing triggers for install-nothing (0.0.0) ..."
}

show_epilogue() {
  printf '\n'
  printf 'All packages installed successfully.\n'
  printf 'Just kidding: no packages were harmed during this session.\n'
  printf 'System state: delightfully unchanged.\n'
}

main() {
  show_apt_preamble
  show_download_phase
  show_unpack_phase
  show_setup_phase
  show_epilogue
}

main
