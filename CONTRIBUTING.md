# Contributing

This repository manages shared infrastructure. Treat every change as an operational change, not a personal dotfiles tweak.

## Dependency workflow

If someone needs a new system dependency or service change on host `116`:

1. open a PR against this repository
2. explain the user need and the exact package or service change
3. wait for `ysun` review
4. after approval, `ysun` performs the rebuild or reinstall

Do not install long-lived dependencies manually on the machine and expect them to survive rebuilds.

For routine update ordering, see [docs/116/maintenance.md](./docs/116/maintenance.md).

## Install and rebuild ownership

- `ysun` is the only declared operator in the current model
- `ysun` is responsible for:
  - secret management
  - `nixos-anywhere` installs
  - rebuilds
  - production service restarts
- `zky` and `wangrongfeng` are trusted research users with Docker access, but no sudo

## Host 116 expectations

- the system SSD is declarative and may be fully rebuilt
- `/data1` is the preserved slow backup volume, not a runtime Docker or model-serving path
- `/home` on the system SSD is treated as disposable during reinstall
- declared users are recreated after reinstall, but personal data still needs an explicit backup or migration plan
