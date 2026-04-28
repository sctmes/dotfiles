#!/usr/bin/env nu

def main [
  target: string = "root@192.168.0.116",
  --extra-dir: string = "/tmp/sctmes-116-extra",
  --proxy: string = "http://192.168.0.249:7897",
  --substituters: string = "https://mirrors.ustc.edu.cn/nix-channels/store",
  --phases: string = "kexec,disko,install,reboot",
] {
  let repo_root = ($env.FILE_PWD | path dirname)
  let persist_dir = ($extra_dir | path join "persist" "var" "lib" "sops-nix")
  let runtime_dir = ($extra_dir | path join "var" "lib" "sops-nix")
  let key_src = "/persist/var/lib/sops-nix/key.txt"
  let key_dst = ($persist_dir | path join "key.txt")
  let runtime_key_dst = ($runtime_dir | path join "key.txt")
  let nix_config = $"substituters = ($substituters)"

  mkdir $persist_dir
  mkdir $runtime_dir
  ^sudo install -m 600 -o $env.USER -g (id -gn) $key_src $key_dst
  ^sudo install -m 600 -o $env.USER -g (id -gn) $key_src $runtime_key_dst

  with-env {
    HTTP_PROXY: $proxy
    HTTPS_PROXY: $proxy
    ALL_PROXY: $proxy
    http_proxy: $proxy
    https_proxy: $proxy
    all_proxy: $proxy
    NIX_CONFIG: $nix_config
    SSH_AUTH_SOCK: ""
  } {
    ^nix run github:nix-community/nixos-anywhere -- --flake $"($repo_root)#116" --option substituters $substituters --build-on local --no-substitute-on-destination --ssh-option IdentityAgent=none --ssh-option IdentitiesOnly=yes --phases $phases --extra-files $extra_dir --generate-hardware-config nixos-generate-config $"($repo_root)/hosts/116/hardware-configuration.nix" --target-host $target
  }
}
