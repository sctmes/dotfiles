{
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.upstream.homeManagerModules.devHeadless
  ];

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

  programs.nushell.loginFile.text = lib.mkForce "";

  dotfiles.maint = {
    enable = true;
    repo = "/home/ysun/github.com/sctmes/dotfiles";
    host = "116";
    riskMarkers = [
      "nvidia-x11"
      "linux-"
      "docker"
      "containerd"
    ];
    updateGroups = {
      tools = [
        "upstream"
      ];
      infra = [
        "sops-nix"
        "impermanence"
        "disko"
      ];
      base = [
        "nixpkgs"
        "home-manager"
      ];
    };
  };

  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      user.name = "Yu Sun";
      user.email = "ysun@sctmes.com";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."github.com" = {
      hostname = "github.com";
      user = "git";
      port = 22;
      identityFile = "~/.ssh/id_ed25519_github";
      identitiesOnly = true;
    };
  };

  home.file.".ssh/id_ed25519_github.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRzq7CIHxYsrrUIW5TFFdea1MbYfkWZx6fQQM6ZBiAd ysun@116-github\n";

  services.ssh-agent.enable = true;
}
