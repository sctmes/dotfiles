{
  inputs,
  lib,
  username,
  ...
}:

{
  imports = [ inputs.upstream.nixosModules.nixProxy ];

  nix.settings.substituters = lib.mkForce [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];
  nix.settings.extra-substituters = lib.mkForce [ ];

  dotfiles.nixProxy = {
    enable = true;
    configPath = "/home/${username}/.config/nix/local-proxy.nuon";
    networkingProxyDefault = "http://192.168.0.249:7897";
    networkingNoProxy = "127.0.0.1,localhost,internal.domain";
    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };
}
