{
  inputs,
  ...
}:

{
  imports = [ inputs.upstream.nixosModules.nixNetwork ];

  nix.settings.extra-substituters = [
    "https://cache.nixos.org"
    "https://yazelix.cachix.org"
  ];

  nix.settings.extra-trusted-public-keys = [
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
}
