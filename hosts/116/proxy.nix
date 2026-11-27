{
  inputs,
  ...
}:

{
  imports = [ inputs.upstream.nixosModules.nixNetwork ];

  nix.settings.extra-substituters = [
    "https://yazelix.cachix.org?priority=60"
  ];

  # Eon 构建按需使用，不加入全机默认 substituters。
  nix.settings.extra-trusted-substituters = [ "https://eon-yazelix.cachix.org" ];

  nix.settings.extra-trusted-public-keys = [
    "eon-yazelix.cachix.org-1:kPIp7u0Gjoz0GNzmRqeaqs798vU2raSOUpK+3xi7oK0="
    "yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM="
  ];

  dotfiles.nixNetwork = {
    profile = "china";
    proxy = {
      enable = true;
      url = "http://127.0.0.1:7890";
    };
    nameservers = [
      "127.0.0.1"
      "192.168.0.1"
    ];
  };

  systemd.services.tailscaled.environment = {
    HTTP_PROXY = "http://127.0.0.1:7890";
    HTTPS_PROXY = "http://127.0.0.1:7890";
    NO_PROXY = "localhost,127.0.0.1";
  };
}
