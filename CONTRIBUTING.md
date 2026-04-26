# Contributing

This repository manages shared infrastructure. Treat every change as an operational change, not a personal dotfiles tweak.

## Dependency workflow

If someone needs a new system dependency or service change on host `116`:

1. open a PR against this repository
2. explain the user need and the exact package or service change
3. wait for `ysun` review
4. after approval, `ysun` performs the rebuild or reinstall

Do not install long-lived dependencies manually on the machine and expect them to survive rebuilds.

## Install and rebuild ownership

- `ysun` is the only declared operator in the current model
- `ysun` is responsible for:
  - secret management
  - `nixos-anywhere` installs
  - rebuilds
  - production service restarts

## Host 116 expectations

- the system SSD is declarative and may be fully rebuilt
- `/data1` is the preserved data volume
- `/home` on the system SSD is treated as disposable during reinstall
- only `ysun` is guaranteed after reinstall in the current phase
