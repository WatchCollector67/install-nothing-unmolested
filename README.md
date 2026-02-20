# install-nothing (bash rewrite)

A Bash-only fake installer that mimics a Debian `apt` / `dpkg` install session.

It theatrically "installs" classic fun UNIX tools like `cowsay`, `sl`, `cmatrix`, `lolcat`, and more — while installing absolutely nothing.

## Run

```bash
./install-nothing.sh
```

No setup, runtime, or extra dependencies needed.

## Options

- `--fast` - skip animation delays for quick demos
- `--seed N` - deterministic pseudo-random output
- `--quiet` - reduce apt-like chatter
- `--help` - show usage

## Example

```bash
./install-nothing.sh --seed 42
```
