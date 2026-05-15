# Host 116

Host `116` is a headless GPU server managed by this repository.

## Current scope

- upstream reuse from `github:bioinformatist/dotfiles`
- system SSD rebuild with `disko`
- preserved `/data1` mdraid/ext4 backup disk
- local `mihomo` proxy service with embedded `metacubexd` UI, backed by a machine-local config file
- Cloudflare DDNS for the public IPv6 `label.bigdick.live` record
- Docker-hosted Label Studio exposed through Caddy at `https://label.bigdick.live`
- Docker-hosted Gemma 4 and transcription shim services
- Home Manager for declared users, with `ysun` retaining Codex and operator-specific configuration
- Docker access for trusted research users `zky` and `wangrongfeng`
- optional SearXNG integration kept disabled by default until its secret policy is finalized

## Documents

- [Install](install.md)
- [Maintenance](maintenance.md)
