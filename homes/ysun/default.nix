{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.upstream.homeManagerModules.devHeadless
  ];

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

  programs.nushell = {
    loginFile.text = lib.mkForce "";
    configFile.text = lib.mkAfter ''
      def maint-update-yzn [] {
        print "Updating Yazelix Next..."
        dotfiles-maint-update "yzn"
      }
    '';
  };

  home.packages = [
    inputs.yazelix-next.packages.${pkgs.stdenv.hostPlatform.system}.yzn
  ];

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
      yzn = [
        "yazelix-next"
      ];
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
