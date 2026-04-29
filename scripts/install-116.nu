#!/usr/bin/env nu

def main [
  target: string = "root@192.168.0.116",
  --extra-dir: string = "/tmp/sctmes-116-extra",
  --proxy: string,
  --substituters: string = "https://mirrors.ustc.edu.cn/nix-channels/store",
  --phases: string = "kexec,disko,install,reboot",
] {
  if ($proxy | is-empty) {
    error make {
      msg: "A LAN proxy is required in mainland China. Pass --proxy http://<lan-proxy>:<port>."
    }
  }

  let repo_root = ($env.FILE_PWD | path dirname)
  let persist_dir = ($extra_dir | path join "persist" "var" "lib" "sops-nix")
  let runtime_dir = ($extra_dir | path join "var" "lib" "sops-nix")
  let proxy_config_dir = ($extra_dir | path join "persist" "home" "ysun" ".config" "nix")
  let proxy_config_dst = ($proxy_config_dir | path join "local-proxy.nuon")
  let key_src = "/persist/var/lib/sops-nix/key.txt"
  let key_dst = ($persist_dir | path join "key.txt")
  let runtime_key_dst = ($runtime_dir | path join "key.txt")
  let nix_config = $"substituters = ($substituters)"
  let no_proxy = "mirrors.ustc.edu.cn,cache.nixos.org,127.0.0.1,localhost,internal.domain"

  mkdir $persist_dir
  mkdir $runtime_dir
  mkdir $proxy_config_dir
  ^sudo install -m 600 -o $env.USER -g (id -gn) $key_src $key_dst
  ^sudo install -m 600 -o $env.USER -g (id -gn) $key_src $runtime_key_dst
  {
    HTTP_PROXY: $proxy
    HTTPS_PROXY: $proxy
    ALL_PROXY: $proxy
    NO_PROXY: $no_proxy
    substituters: [ $substituters ]
  } | to nuon | save --force $proxy_config_dst

  with-env {
    HTTP_PROXY: $proxy
    HTTPS_PROXY: $proxy
    ALL_PROXY: $proxy
    http_proxy: $proxy
    https_proxy: $proxy
    all_proxy: $proxy
    NO_PROXY: $no_proxy
    no_proxy: $no_proxy
    NIX_CONFIG: $nix_config
    SSH_AUTH_SOCK: ""
  } {
    ^nix run github:nix-community/nixos-anywhere -- --flake $"($repo_root)#116" --option substituters $substituters --build-on local --no-substitute-on-destination --ssh-option IdentityAgent=none --ssh-option IdentitiesOnly=yes --phases $phases --extra-files $extra_dir --generate-hardware-config nixos-generate-config $"($repo_root)/hosts/116/hardware-configuration.nix" --target-host $target
  }
}
