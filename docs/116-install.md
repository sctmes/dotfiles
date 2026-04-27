# Host 116 Install

This repository manages host `116` by composing:

- `upstream.profiles.headless`
- `upstream.profiles.ai-serving`
- upstream Home Manager modules for `ysun` (`Codex + headless TUI dev`)
- local `mihomo` Docker compose management with embedded `metacubexd` UI
- local `disko` for the system SSD
- local `/data1` mdraid/ext4 reuse
- local Docker compose definitions for the assistant stack

This install is intentionally destructive for the system SSD.

## Current hardware assumptions

- system disk: `/dev/disk/by-id/ata-INTEL_SSDSC2KB019T8_PHYF110300SW1P9DGN`
- data disks:
  - `/dev/disk/by-id/wwn-0x5000c50083a3302f`
  - `/dev/disk/by-id/wwn-0x5000c50083e9b7f7`
- data array UUID: `d3818b39:8ab2ff8b:0c735c67:1ec5c9d8`
- `/data1` filesystem UUID: `16530ffc-a911-476d-a071-9e368d236e57`

## Before install

1. Verify `secrets/hosts/116.yaml` still contains the intended `ysun-password` hash.
2. Make sure the age private key exists at `/persist/var/lib/sops-nix/key.txt` on the operator machine.
3. Make sure the company operations private key at `~/.ssh/id_ed25519_sctmes_ops` is available on the operator machine.
4. Move or copy the current model tree to `/data1/ai-serving/models`.
   Current live system stores models under `/home/ysun/models`; the managed target location is `/data1/ai-serving/models`.
5. If you later enable SearXNG, add its secret back into `secrets/hosts/116.yaml` before switching.
6. Confirm the LAN proxy `http://192.168.0.249:7897` is reachable from both the operator machine and `116`, or pass a different proxy URL to the install script.
7. Decide whether post-install `nix` traffic should keep using that LAN proxy or later switch to local `mihomo` on `127.0.0.1:7890`.

## Remote install

Run:

```nu
nu ./scripts/install-116.nu root@192.168.0.116
```

That uses `nixos-anywhere` with this repo's `#116` configuration, injects `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` plus USTC substituters for the install session, and copies the sops age key into `/mnt/persist/var/lib/sops-nix/key.txt`.
It also writes a generated `hosts/116/hardware-configuration.nix` back into this repo for future rebuilds.

If the proxy address changes, override it explicitly:

```nu
nu ./scripts/install-116.nu root@192.168.0.116 --proxy http://<lan-proxy>:7897
```

## What gets rebuilt

- the Intel system SSD is wiped and rebuilt with GPT + EFI + btrfs
- `/` becomes tmpfs
- `/nix`, `/persist`, `/home`, and `/swap` live on btrfs subvolumes
- `/swap/swapfile` provides a 16G emergency swapfile
- `/home` persists as its own btrfs subvolume after install, but the old `/home` on the wiped system SSD is not preserved
- `/data1` is preserved and remounted from the existing mdraid array
- host firewall is intentionally disabled in this revision

## Service layout after switch

- `jarvis-vllm-compose.service`
  exposes:
  - `8080` for Gemma 4 OpenAI-compatible API
  - `8090` for the transcription compatibility shim
- `mihomo-compose.service`
  is installed but only starts once `/persist/mihomo/config.yaml` exists

## User environment after switch

- `ysun` gets a Home Manager profile layered on top of the host config
- that profile reuses upstream `Codex` config and trusts both:
  - `/home/ysun/github.com/bioinformatist/dotfiles`
  - `/home/ysun/github.com/sctmes/dotfiles`
- `ysun` also gets a minimal headless TUI setup:
  - `nushell`
  - `helix`
  - `yazi`
  - `fzf`
  - `zoxide`
  - `ripgrep`
  - `sops`
  - `ouch`
- `ysun` also gets `~/.config/nix/local-proxy.nuon`, prefilled with:
  - `http://192.168.0.249:7897`
  - USTC store mirror + `https://cache.nixos.org`
- `nix-daemon` reads the same file at boot, so post-install `nix` / `nixos-rebuild` keep using the same proxy and substituters

## Local mihomo config

This repository does not store the real subscription URL.

Instead, create `/persist/mihomo/config.yaml` directly on `116` after install.
Once that file exists, `mihomo-compose.service` can start and will mount the whole `/persist/mihomo` directory into the container.
The `/persist/mihomo` directory is created for `ysun`, so you can update the local config without changing the declarative repo.

The local config should at least include:

- `mixed-port: 7890`
- `allow-lan: true`
- `external-controller: 0.0.0.0:9090`
- `secret: <fill-your-lan-shared-secret>`
- `external-ui: ./ui`
- `external-ui-name: metacubexd`
- `external-ui-url: https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip`
- `tun.enable: true`

After writing the file:

```bash
sudo systemctl start mihomo-compose.service
```

If you want the machine to use its own local proxy after that, update `~/.config/nix/local-proxy.nuon` from `http://192.168.0.249:7897` to `http://127.0.0.1:7890` and restart `nix-daemon`.

## Immediate post-install bootstrap

After `nixos-anywhere` finishes, the shortest path to a usable machine is:

1. Log in as `ysun` with either the configured password or the company operations SSH key.
2. Create `/persist/mihomo/config.yaml`.
3. Fill the local Mihomo config with:
   - your real subscription URL
   - a LAN-shared `secret` value
   - the minimum fields listed above for `mixed-port`, `external-controller`, `external-ui`, and `tun`
4. Start Mihomo:

```bash
sudo systemctl start mihomo-compose.service
```

5. If desired, switch `~/.config/nix/local-proxy.nuon` from the temporary LAN proxy to `http://127.0.0.1:7890`, then restart `nix-daemon`.
6. Clone `sctmes/dotfiles` to `/home/ysun/github.com/sctmes/dotfiles`.
7. Log in to `codex` manually and continue iterating from the server.

## Notes

- This repo currently tracks the real live assistant stack on 116:
  Gemma 4 E4B plus the transcription shim, not the older Qwen plus speaches model setup.
- SearXNG is intentionally not enabled by default in this revision because its secret handling is still under discussion.
- `ysun` is the only guaranteed account after reinstall; colleague accounts are intentionally not preserved in this phase.
