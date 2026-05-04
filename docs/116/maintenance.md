# Host 116 Maintenance

Host `116` uses upstream headless Nushell maintenance helpers configured for
this repository and host.

## Upstream Codex and tool updates

Codex pin updates belong to the upstream desktop maintenance flow.

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
the updated upstream flake input.

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
