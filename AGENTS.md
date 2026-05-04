# SCTMES NixOS Host Dotfiles

## Repo Scope

This repository is the downstream NixOS management repo for SCTMES-owned hosts.
At the moment it manages only host `116`, a headless GPU server.

Treat changes here as operational infrastructure changes, not personal workstation tweaks.

## Critical Non-Obvious Behaviors

### Headless Host Assumption

Host `116` is headless.
Do not assume a desktop session, local browser, clipboard integration, or any GUI recovery path.
Prefer SSH, TUI tools, systemd inspection, logs, and file-based configuration changes.

### Nushell-First Workflow

The repo's shell workflow is Nushell-first.
Prefer Nushell syntax when writing or updating repo commands, examples, and helper scripts.

When executing Nushell snippets through Codex tools, do not rely on the tool's shell selection alone.
Invoke Nushell explicitly as `nu -c '...'`, otherwise the command may still be interpreted by `/bin/sh`.

### Proxy Configuration Is Runtime State

This repo intentionally does not hardcode a universal install proxy.
The install path expects a site-local LAN proxy passed at runtime to `scripts/install-116.nu`.

If network access looks broken during install or rebuild work, inspect:

- `~/.config/nix/local-proxy.nuon`
- `homes/ysun/default.nix`
- `hosts/116/proxy.nix`
- `docs/116/install.md`

Do not replace runtime proxy inputs with guessed repo defaults.

## Key Constraints

- Secrets must go through `sops-nix`. Do not commit plaintext secrets, tokens, private keys, subscription URLs, or generated secret material.
- Scope changes surgically. This repo currently manages `.#116`; do not generalize for imaginary future hosts unless the user asks.
- Prefer updating the declarative source of truth under `hosts/116/`, `homes/ysun/`, `scripts/`, `docs/`, and `secrets/hosts/116.yaml` instead of applying long-lived manual fixes on the machine.
- Preserve the headless operating model. Do not add GUI-only dependencies, desktop services, or steps that require local display access unless explicitly requested.
- `scripts/install-116.nu` is the canonical install entrypoint. Keep examples aligned with `nu ./scripts/install-116.nu root@192.168.0.116 --proxy http://<lan-proxy>:<port>`.
- System-level deployment flows in this repo are `nixos-rebuild` for an existing machine and `nixos-anywhere` via `scripts/install-116.nu` for fresh install or reprovisioning. Do not invent alternate deployment paths unless the repo is updated to support them.
- Rebuild examples should target this flake explicitly, typically `sudo nixos-rebuild switch --flake .#116`.
- Treat the system SSD as disposable during reinstall and `/data1` as the preserved data volume. Do not suggest workflows that rely on the old system SSD state surviving reinstall.
- Changes are verified by the operator after rebuild or reinstall. If you cannot run a rebuild in the current environment, say so clearly instead of claiming full verification.
- Match the existing repo style: minimal Nix modules, minimal Nushell scripts, no speculative abstractions, no adjacent cleanup.
- Use Conventional Commits for commit subjects: `<type>: <summary>`. Common types here are `feat`, `fix`, `chore`, `docs`, and `refactor`. Keep the summary short and consistent with the existing lowercase style.

## Documentation

Reference existing docs instead of duplicating them:

- `README.md` for the host matrix entry point
- `CONTRIBUTING.md` for change ownership and rebuild ownership
- `docs/README.md` for documentation entry points
- `docs/116/install.md` for install, proxy, persistence, and post-install bootstrap
- `docs/116/maintenance.md` for routine maintenance and update workflow
