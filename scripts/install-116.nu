#!/usr/bin/env nu

def main [
  target: string = "root@192.168.0.116",
  extra_dir: string = "/tmp/sctmes-116-extra",
  proxy: string = "http://192.168.0.249:7897",
] {
  let repo_root = ($env.FILE_PWD | path dirname)
  let persist_dir = ($extra_dir | path join "persist" "var" "lib" "sops-nix")
  let runtime_dir = ($extra_dir | path join "var" "lib" "sops-nix")
  let key_src = "/persist/var/lib/sops-nix/key.txt"
  let key_dst = ($persist_dir | path join "key.txt")
  let runtime_key_dst = ($runtime_dir | path join "key.txt")
  let nix_config = "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"

  mkdir $persist_dir
  mkdir $runtime_dir
  cp $key_src $key_dst
  cp $key_src $runtime_key_dst

  with-env {
    HTTP_PROXY: $proxy
    HTTPS_PROXY: $proxy
    ALL_PROXY: $proxy
    http_proxy: $proxy
    https_proxy: $proxy
    all_proxy: $proxy
    NIX_CONFIG: $nix_config
  } {
    nix run github:nix-community/nixos-anywhere -- 
      --flake $"($repo_root)#116" 
      --extra-files $extra_dir 
      --generate-hardware-config nixos-generate-config $"($repo_root)/hosts/116/hardware-configuration.nix"
      --target-host $target
  }
}
