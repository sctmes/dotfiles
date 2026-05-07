# Host 116 Maintenance

Host `116` uses upstream headless Nushell maintenance helpers configured for
this repository and host.

## Upstream Codex and tool updates

Codex pin updates belong to the upstream desktop maintenance flow. Codex is a
deliberate exception among tools: keep it pinned to the official OpenAI GitHub
release binary. Do not add a downstream headless `maint-refresh-codex` path for
`116`.

Other tool updates should stay binary-friendly. Prefer updates that keep using
binary caches, existing flake inputs, or upstream-provided binary releases. Do
not add source-heavy tooling to the routine tools path unless that build cost is
explicitly accepted for this host.

1. In the upstream repository, run:

   ```nu
   maint-update-tools
   ```

2. Commit and push the upstream changes.
3. In this downstream repository, run:

   ```nu
   maint-update-tools
   maint-check
   maint-switch
   ```

Downstream `maint-update-tools` updates the host-declared tools group. For
`116`, that group includes the `upstream` input, so Codex updates arrive through
the updated upstream flake input. Base and infrastructure inputs used by both
repositories follow the downstream inputs, so routine upstream updates do not
move `sops-nix`, `impermanence`, `disko`, `home-manager`, or `nixpkgs`.

## Infrastructure updates

Use the infrastructure path for low-frequency host infrastructure inputs:

```nu
maint-update-infra
maint-check
maint-switch
```

For `116`, this group includes:

- `sops-nix`
- `impermanence`
- `disko`

This path may build local helper programs, such as `sops-install-secrets`, so do
not include it in the routine tools refresh.

## Base updates

Use the base path only during a maintenance window:

```nu
maint-update-base
maint-check
maint-switch
```

`maint-update-base` updates `nixpkgs` and `home-manager`, so it may move the
kernel, NVIDIA driver, Docker/containerd, and systemd.

## Check policy

`maint-check` highlights:

- `nvidia-x11`
- `linux-`
- `docker`
- `containerd`

It intentionally does not check `cuda*` because CUDA user-space libraries belong
inside containers on this host.

`maint-switch` never updates flake inputs by itself. It only applies the current
repository state with `sudo nixos-rebuild switch --flake ...#116`.

After switching, open a new Nushell session before checking which `maint-*`
functions are available. Existing shells may still hold old function
definitions.

## Long-term upstream boundary

The long-term target is a lighter upstream reusable/headless flake boundary for
server consumers like `116`. Updating `upstream` may still bring desktop-only
transitive lock metadata from the full upstream flake; those inputs should not
enter the `116` closure, but the cleaner end state is an upstream interface that
does not expose desktop-only inputs to headless downstream repositories.
