# install-nothing (bash rewrite)

A pure Bash, harmless fake installer that mimics package manager output styles:

- Debian / APT
- Fedora / DNF
- Arch / Pacman

It never executes `apt`, `dnf`, `pacman`, or installs anything.

## Usage

```bash
./install-nothing.sh [options]
```

## Key options

- `-m, --manager <debian|fedora|arch|apt|dnf|pacman>`
- `-p, --packages <list>` (comma and/or space separated; repeatable)
- `--speed <slow|medium|fast|NUMBER>` (NUMBER is Mbps, e.g. `12.5`)
- `--seed <string|int>` deterministic output
- `--color <auto|always|never>` or `--no-color`
- `-y, --assume-yes`
- `--dry-run`
- `-q, --quiet`
- `-v, --verbose`
- `--version`
- `-h, --help`

## Examples

```bash
./install-nothing.sh --manager fedora --packages "neofetch,htop" --speed fast
./install-nothing.sh -m arch -p "base-devel git" --speed 50
./install-nothing.sh --manager debian -p curl -p wget --seed 42
```

## Notes

- Running with no args keeps default Debian/APT style and a fun default package list.
- `--seed` guarantees stable output for the same arguments.
- `--speed slow` is visibly slower than `--speed fast` but still short-lived.
