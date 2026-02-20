#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="install-nothing"
readonly APP_VERSION="3.0.0"

DEFAULT_MANAGER="apt"
DEFAULT_SPEED="medium"
COLOR_MODE="auto"
ASSUME_YES=0
DRY_RUN=0
QUIET=0
VERBOSE=0
SEED_INPUT=""
SEED_INT=0
RNG_STATE=1
LEGACY_FAST=0

packages=()
default_packages=(sl cowsay fortune-mod cmatrix lolcat neofetch htop figlet toilet ninvaders asciiquarium)

show_help() {
  cat <<'USAGE'
install-nothing v3.0.0

Fake package installer simulator (harmless): apt/dnf/pacman-style output only.
No real package manager is executed.

Usage:
  ./install-nothing.sh [options]

Options:
  -m, --manager <debian|fedora|arch|apt|dnf|pacman>
  -p, --packages <list>      Comma/space-separated package list (repeatable)
      --speed <slow|medium|fast|NUMBER>
      --seed <string|int>
      --color <auto|always|never>
      --no-color
  -y, --assume-yes
      --dry-run
  -q, --quiet
  -v, --verbose
      --fast                 Backward-compatible alias for --speed fast
      --version
  -h, --help

Examples:
  ./install-nothing.sh --manager fedora --packages "neofetch,htop" --speed fast
  ./install-nothing.sh -m arch -p "base-devel git" --speed 50
  ./install-nothing.sh --manager debian -p curl -p wget --seed 42
USAGE
}

show_version() { printf '%s v%s\n' "$APP_NAME" "$APP_VERSION"; }
error() { printf 'error: %s\n' "$*" >&2; }

seed_to_int() {
  local raw="$1" i ch ord acc=0
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf '%d' "$((raw % 32768))"
    return
  fi
  for ((i=0; i<${#raw}; i++)); do
    ch="${raw:i:1}"
    printf -v ord '%d' "'$ch"
    acc=$(((acc * 131 + ord + i) % 32768))
  done
  printf '%d' "$acc"
}

normalize_manager() {
  case "$1" in
    apt|debian) printf 'apt' ;;
    dnf|fedora) printf 'dnf' ;;
    pacman|arch) printf 'pacman' ;;
    *) return 1 ;;
  esac
}

validate_package_name() { [[ -n "$1" && "$1" =~ ^[a-zA-Z0-9._+-]+$ ]]; }

split_package_list() {
  local input="$1" normalized token
  normalized=${input//,/ }
  for token in $normalized; do packages+=("$token"); done
}

is_numeric_speed() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }

mbps_to_kbps() {
  local val="$1" whole frac
  if [[ "$val" == *.* ]]; then
    whole=${val%%.*}
    frac=${val#*.}
    frac=${frac:0:2}
    while ((${#frac} < 2)); do frac+="0"; done
  else
    whole="$val"
    frac="00"
  fi
  printf '%d' "$((10#${whole} * 125 + 10#${frac} * 125 / 100))"
}

parse_args() {
  MANAGER="$DEFAULT_MANAGER"
  SPEED_RAW="$DEFAULT_SPEED"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help; exit 0 ;;
      --version) show_version; exit 0 ;;
      -m|--manager) [[ $# -ge 2 ]] || { error "--manager requires a value"; exit 2; }; MANAGER="$2"; shift 2 ;;
      --manager=*) MANAGER="${1#*=}"; shift ;;
      -p|--packages) [[ $# -ge 2 ]] || { error "--packages requires a value"; exit 2; }; split_package_list "$2"; shift 2 ;;
      --packages=*) split_package_list "${1#*=}"; shift ;;
      --speed) [[ $# -ge 2 ]] || { error "--speed requires a value"; exit 2; }; SPEED_RAW="$2"; shift 2 ;;
      --speed=*) SPEED_RAW="${1#*=}"; shift ;;
      --seed) [[ $# -ge 2 ]] || { error "--seed requires a value"; exit 2; }; SEED_INPUT="$2"; shift 2 ;;
      --seed=*) SEED_INPUT="${1#*=}"; shift ;;
      --no-color) COLOR_MODE="never"; shift ;;
      --color) [[ $# -ge 2 ]] || { error "--color requires a value"; exit 2; }; COLOR_MODE="$2"; shift 2 ;;
      --color=*) COLOR_MODE="${1#*=}"; shift ;;
      -y|--assume-yes) ASSUME_YES=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -q|--quiet) QUIET=1; shift ;;
      -v|--verbose) VERBOSE=1; shift ;;
      --fast) LEGACY_FAST=1; SPEED_RAW="fast"; shift ;;
      --) shift; break ;;
      -*) error "unknown option: $1"; exit 2 ;;
      *) split_package_list "$1"; shift ;;
    esac
  done
  while [[ $# -gt 0 ]]; do split_package_list "$1"; shift; done
}

setup_color() {
  case "$COLOR_MODE" in
    auto)
      if [[ -t 1 ]]; then USE_COLOR=1; else USE_COLOR=0; fi
      ;;
    always) USE_COLOR=1 ;;
    never) USE_COLOR=0 ;;
    *) error "invalid --color value: $COLOR_MODE (expected auto|always|never)"; exit 2 ;;
  esac
  if [[ "$USE_COLOR" -eq 1 ]]; then
    C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_INFO=$'\033[1;34m'; C_OK=$'\033[1;32m'; C_WARN=$'\033[1;33m'
  else
    C_RESET=""; C_DIM=""; C_INFO=""; C_OK=""; C_WARN=""
  fi
}

setup_speed() {
  case "$SPEED_RAW" in
    slow) BASE_DELAY_MS=110; BASE_RATE_KB=400 ;;
    medium) BASE_DELAY_MS=55; BASE_RATE_KB=1500 ;;
    fast) BASE_DELAY_MS=20; BASE_RATE_KB=5200 ;;
    *)
      if is_numeric_speed "$SPEED_RAW"; then
        BASE_RATE_KB="$(mbps_to_kbps "$SPEED_RAW")"
        (( BASE_RATE_KB < 100 )) && BASE_RATE_KB=100
        (( BASE_RATE_KB > 50000 )) && BASE_RATE_KB=50000
        if (( BASE_RATE_KB < 900 )); then BASE_DELAY_MS=110
        elif (( BASE_RATE_KB < 3000 )); then BASE_DELAY_MS=55
        else BASE_DELAY_MS=20
        fi
      else
        error "invalid --speed value: $SPEED_RAW (expected slow|medium|fast|NUMBER)"
        exit 2
      fi
      ;;
  esac
  if [[ "$LEGACY_FAST" -eq 1 ]]; then
    BASE_DELAY_MS=0
  fi
}


delay_ms() { local ms="$1" sec; (( ms <= 0 )) && return 0; printf -v sec '0.%03d' "$ms"; sleep "$sec"; }

rand_raw() {
  RNG_STATE=$(((RNG_STATE * 1103515245 + 12345) & 0x7fffffff))
  printf '%d' "$RNG_STATE"
}

rand_between() { local min="$1" max="$2" raw; raw=$(rand_raw); printf '%d' "$((min + raw % (max - min + 1)))"; }
print_line() {
  if [[ "$QUIET" -eq 1 ]]; then
    return 0
  fi
  printf '%b\n' "$1"
}

print_verbose() {
  if [[ "$VERBOSE" -ne 1 ]]; then
    return 0
  fi
  printf '%b\n' "${C_DIM}$1${C_RESET}"
}

progress_bar() {
  local pct="$1" done="$2" total="$3" rate="$4" unit="$5"
  local width=24 fill empty bar1 bar2
  fill=$((pct * width / 100)); empty=$((width - fill))
  printf -v bar1 '%*s' "$fill" ''; bar1=${bar1// /#}
  printf -v bar2 '%*s' "$empty" ''; bar2=${bar2// /.}
  printf '\r%3d%% [%s%s] %d/%d %s  %d %s/s' "$pct" "$bar1" "$bar2" "$done" "$total" "$unit" "$rate" "$unit"
}

simulate_download() {
  local pkg="$1" size="$2" unit="$3" steps=10 i done pct rate
  print_verbose "[sim] ${pkg}: ${size}${unit}, speed=${SPEED_RAW}, seed=${SEED_INPUT:-default}"
  for ((i=1; i<=steps; i++)); do
    done=$((size * i / steps)); pct=$((i * 100 / steps))
    rate=$(rand_between $((BASE_RATE_KB * 8 / 10)) $((BASE_RATE_KB * 12 / 10 + 1)))
    progress_bar "$pct" "$done" "$size" "$rate" "$unit"
    delay_ms $((BASE_DELAY_MS + $(rand_between 0 29)))
  done
  printf '\n'
}

summary_banner() {
  printf '%b\n' "${C_INFO}==> Using ${1} output skin${C_RESET}"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    printf '%b\n' "${C_DIM}(non-interactive: --assume-yes)${C_RESET}"
  fi
}

render_apt_install() {
  local pkg total=0 size
  summary_banner "APT/Debian"
  print_line "Reading package lists... Done"
  print_line "Building dependency tree... Done"
  print_line "Reading state information... Done"
  print_line "The following NEW packages will be installed:"
  print_line "  ${packages[*]}"
  print_line "0 upgraded, ${#packages[@]} newly installed, 0 to remove and $(rand_between 0 22) not upgraded."
  for pkg in "${packages[@]}"; do size=$(rand_between 150 2200); total=$((total + size)); done
  print_line "Need to get ${total} kB of archives."
  print_line "After this operation, $((total + $(rand_between 500 4000))) kB of additional disk space will be used."
  for pkg in "${packages[@]}"; do
    size=$(rand_between 150 2200)
    print_line "Get:1 http://deb.debian.org/debian stable/main amd64 ${pkg} all 1.0 [${size} kB]"
    simulate_download "$pkg" "$size" "kB"
    print_line "Selecting previously unselected package ${pkg}."
    print_line "Preparing to unpack .../${pkg}_1.0.deb ..."
    print_line "Unpacking ${pkg} (1.0) ..."
    delay_ms "$BASE_DELAY_MS"
  done
  for pkg in "${packages[@]}"; do print_line "Setting up ${pkg} (1.0) ..."; delay_ms "$BASE_DELAY_MS"; done
  print_line "Processing triggers for man-db (2.11.2-2) ..."
}

render_dnf_install() {
  local pkg size idx=1
  summary_banner "DNF/Fedora"
  print_line "Fedora 39 - x86_64"
  print_line "Metadata cache created."
  print_line "Dependencies resolved."
  print_line "================================================================================"
  print_line " Package           Architecture     Version     Repository                 Size"
  print_line "================================================================================"
  for pkg in "${packages[@]}"; do print_line " ${pkg}            x86_64           1.0-1       install-nothing          $(rand_between 40 700) k"; done
  print_line "\nTransaction Summary"
  print_line "Install  ${#packages[@]} Packages"
  if [[ "$ASSUME_YES" -eq 0 ]]; then
    print_line "Is this ok [y/N]: y"
  fi
  for pkg in "${packages[@]}"; do
    size=$(rand_between 200 3500)
    print_line "Downloading Packages:"
    print_line "${pkg}-1.0-1.x86_64.rpm"
    simulate_download "$pkg" "$size" "kB"
  done
  print_line "Running transaction check"
  print_line "Running transaction test"
  print_line "Transaction test succeeded"
  print_line "Running transaction"
  for pkg in "${packages[@]}"; do
    print_line "  Installing       : ${pkg}-1.0-1.x86_64                              [${idx}/${#packages[@]}]"
    idx=$((idx + 1))
    delay_ms "$BASE_DELAY_MS"
  done
  print_line "Complete!"
}

render_pacman_install() {
  local pkg size idx=1
  summary_banner "Pacman/Arch"
  print_line ":: Synchronizing package databases..."
  print_line " core downloading..."
  print_line " extra downloading..."
  print_line ":: Starting full system upgrade..."
  print_line "resolving dependencies..."
  print_line "looking for conflicting packages..."
  print_line "\nPackages (${#packages[@]}) ${packages[*]}"
  print_line "\nTotal Download Size:   $(rand_between 2 40).$(rand_between 0 9) MiB"
  print_line "Total Installed Size:  $(rand_between 6 80).$(rand_between 0 9) MiB"
  if [[ "$ASSUME_YES" -eq 0 ]]; then
    print_line ":: Proceed with installation? [Y/n] Y"
  fi
  for pkg in "${packages[@]}"; do
    size=$(rand_between 300 2800)
    print_line ":: Retrieving packages..."
    print_line " ${pkg}-1.0-1-x86_64.pkg.tar.zst"
    simulate_download "$pkg" "$size" "KiB"
  done
  for pkg in "${packages[@]}"; do
    print_line "(${idx}/${#packages[@]}) checking keys in keyring"
    print_line "(${idx}/${#packages[@]}) checking package integrity"
    print_line "(${idx}/${#packages[@]}) loading package files"
    print_line "(${idx}/${#packages[@]}) checking for file conflicts"
    print_line "(${idx}/${#packages[@]}) installing ${pkg}"
    idx=$((idx + 1))
    delay_ms "$BASE_DELAY_MS"
  done
}

main() {
  parse_args "$@"

  local normalized
  if ! normalized="$(normalize_manager "$MANAGER")"; then
    error "invalid manager: $MANAGER (expected debian|fedora|arch|apt|dnf|pacman)"
    exit 2
  fi
  MANAGER="$normalized"

  if [[ -z "$SEED_INPUT" ]]; then
    SEED_INPUT="install-nothing"
  fi
  SEED_INT="$(seed_to_int "$SEED_INPUT")"
  RNG_STATE="$SEED_INT"

  if [[ "${#packages[@]}" -eq 0 ]]; then packages=("${default_packages[@]}"); fi

  local i
  for i in "${!packages[@]}"; do
    if ! validate_package_name "${packages[$i]}"; then
      error "invalid package name: '${packages[$i]}'"
      error "allowed characters: a-z A-Z 0-9 . _ + -"
      exit 2
    fi
  done

  setup_color
  setup_speed

  case "$MANAGER" in
    apt) render_apt_install ;;
    dnf) render_dnf_install ;;
    pacman) render_pacman_install ;;
  esac

  printf '%b\n' "${C_OK}Done. Installed exactly nothing.${C_RESET}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%b\n' "${C_WARN}[dry-run] Simulation only: no packages were installed and no manager was executed.${C_RESET}"
  fi
}

main "$@"
