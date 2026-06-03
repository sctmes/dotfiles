#!/usr/bin/env nu

def main [
  target: string = "root@192.168.0.116",
  --extra-dir: string = "/tmp/sctmes-116-extra",
  --proxy: string,
  --substituters: string = "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org",
  --extra-substituters: string = "https://yazelix.cachix.org",
  --extra-trusted-public-keys: string = "yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM=",
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
  let key_src = "/persist/var/lib/sops-nix/key.txt"
  let key_dst = ($persist_dir | path join "key.txt")
  let runtime_key_dst = ($runtime_dir | path join "key.txt")
  let nix_config = $"substituters = ($substituters)\nextra-substituters = ($extra_substituters)\nextra-trusted-public-keys = ($extra_trusted_public_keys)"
  let no_proxy = "mirrors.ustc.edu.cn,cache.nixos.org,127.0.0.1,localhost"
  let expected_extra_substituters = ($extra_substituters | split row " " | where {|item| not ($item | is-empty) })
  let expected_extra_trusted_public_keys = ($extra_trusted_public_keys | split row " " | where {|item| not ($item | is-empty) })
  let effective_nix_config = (with-env { NIX_CONFIG: $nix_config } { ^nix config show --json | from json })
  let effective_substituters = $effective_nix_config.substituters.value
  let effective_trusted_public_keys = $effective_nix_config."trusted-public-keys".value
  let missing_substituters = ($expected_extra_substituters | where {|url| not ($effective_substituters | any {|configured| $configured == $url }) })
  let missing_trusted_public_keys = ($expected_extra_trusted_public_keys | where {|key| not ($effective_trusted_public_keys | any {|configured| $configured == $key }) })

  if ((not ($missing_substituters | is-empty)) or (not ($missing_trusted_public_keys | is-empty))) {
    error make {
      msg: $"Install-time Nix cache settings were ignored. Missing substituters: (($missing_substituters | str join ', ')); missing trusted public keys: (($missing_trusted_public_keys | str join ', ')). Run from a Nix trusted user or configure the operator machine's Nix daemon before reinstalling."
    }
  }

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
    NO_PROXY: $no_proxy
    no_proxy: $no_proxy
    NIX_CONFIG: $nix_config
    SSH_AUTH_SOCK: ""
  } {
    ^nix run github:nix-community/nixos-anywhere -- --flake $"($repo_root)#116" --option substituters $substituters --option extra-substituters $extra_substituters --option extra-trusted-public-keys $extra_trusted_public_keys --build-on local --no-substitute-on-destination --ssh-option IdentityAgent=none --ssh-option IdentitiesOnly=yes --phases $phases --extra-files $extra_dir --generate-hardware-config nixos-generate-config $"($repo_root)/hosts/116/hardware-configuration.nix" --target-host $target
  }
}
