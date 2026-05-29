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

  dotfiles.nixProxy = {
    enable = true;
    configPath = "/home/${username}/.config/nix/local-proxy.nuon";
    nameservers = [
      "127.0.0.1"
      "192.168.0.1"
    ];
  };
}
