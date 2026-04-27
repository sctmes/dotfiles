# sctmes/dotfiles

Downstream NixOS management for SCTMES-owned hosts.

Current scope:

- host `116` on `192.168.0.116`
- upstream reuse from `github:bioinformatist/dotfiles`
- system SSD rebuild with `disko`
- preserved `/data1` mdraid/ext4 data disk
- local `mihomo` proxy service with embedded `metacubexd` UI, backed by a machine-local config file
- Docker-hosted Gemma 4 and transcription shim services
- Home Manager for `ysun`, reusing upstream Codex plus a headless TUI dev profile
- optional SearXNG integration kept disabled by default until its secret policy is finalized

Start with [docs/116-install.md](./docs/116-install.md).
For team workflow, see [CONTRIBUTING.md](./CONTRIBUTING.md).
