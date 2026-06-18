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

### Documentation Language

Repository-facing documentation should be written in Chinese because the
current audience is Chinese-speaking. Keep commands, paths, service names,
package names, product names, badges, established English technical terms, and
other technical identifiers in their original form when a literal Chinese
translation would be awkward or misleading.

`AGENTS.md` is the exception: keep this file in English so agent instructions
remain unambiguous for coding agents.

### Nushell-First Workflow

The repo's shell workflow is Nushell-first.
Prefer Nushell syntax when writing or updating repo commands, examples, and helper scripts.

When executing Nushell snippets through Codex tools, do not rely on the tool's shell selection alone.
Invoke Nushell explicitly as `nu -c '...'`, otherwise the command may still be interpreted by `/bin/sh`.

### Proxy Configuration Is Declarative

This repo intentionally does not hardcode a universal install-time proxy.
The install path accepts a site-local LAN proxy as a runtime argument to
`scripts/install-116.nu`, but steady-state Nix proxy and cache behavior is
declared through `hosts/116/proxy.nix` and the upstream `nixNetwork` module.

If network access looks broken during install or rebuild work, inspect:

- `hosts/116/proxy.nix`
- `scripts/install-116.nu`
- `docs/116/README.md`

Do not reintroduce long-lived mutable proxy files for steady-state Nix behavior.

## Key Constraints

- Secrets must go through `sops-nix`. Do not commit plaintext secrets, tokens, private keys, subscription URLs, or generated secret material.
- Scope changes surgically. This repo currently manages `.#116`; do not generalize for imaginary future hosts unless the user asks.
- Prefer updating the declarative source of truth under `hosts/116/`, `homes/ysun/`, `scripts/`, `docs/`, `secrets/hosts/116.yaml`, and per-user SOPS files instead of applying long-lived manual fixes on the machine.
- Preserve the headless operating model. Do not add GUI-only dependencies, desktop services, or steps that require local display access unless explicitly requested.
- Keep Codex updates upstream-owned. Do not reintroduce a downstream headless `maint-refresh-codex`; `116` receives Codex updates by updating the `upstream` flake input after upstream refreshes the official OpenAI release binary pin.
- Keep routine tool updates binary-friendly. Before adding inputs to the tools maintenance group, consider whether they normally use binary caches or upstream-provided release binaries instead of expensive local source builds. Put low-frequency infrastructure inputs such as `sops-nix`, `impermanence`, and `disko` in the infra maintenance group instead.
- Long-term upstream direction: prefer a lighter reusable/headless flake boundary so headless downstream hosts do not see desktop-only upstream inputs in routine maintenance.
- `scripts/install-116.nu` is the canonical install entrypoint. Keep examples aligned with `nu ./scripts/install-116.nu root@192.168.0.116 --proxy http://<lan-proxy>:<port>`.
- System-level deployment flows in this repo are `nixos-rebuild` for an existing machine and `nixos-anywhere` via `scripts/install-116.nu` for fresh install or reprovisioning. Do not invent alternate deployment paths unless the repo is updated to support them.
- Rebuild examples should target this flake explicitly, typically `sudo nixos-rebuild switch --flake .#116`.
- Treat the system SSD as disposable during reinstall and `/data1` as the preserved data volume. Do not suggest workflows that rely on the old system SSD state surviving reinstall.
- Changes are verified by the operator after rebuild or reinstall. If you cannot run a rebuild in the current environment, say so clearly instead of claiming full verification.
- Match the existing repo style: minimal Nix modules, minimal Nushell scripts, no speculative abstractions, no adjacent cleanup.
- Use Conventional Commits for commit subjects: `<type>: <summary>`. Common types here are `feat`, `fix`, `chore`, `docs`, and `refactor`. Keep the summary short and consistent with the existing lowercase style.

## Documentation

Reference existing docs instead of duplicating them:

- `README.md` for the repository entry point
- `CONTRIBUTING.md` for change ownership and rebuild ownership
- `docs/README.md` for documentation entry points
- `docs/116/README.md` for host 116 usage, install, maintenance, storage, and GitHub token enrollment
