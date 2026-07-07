{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  upstreamMaintPolicy = builtins.fromJSON (
    builtins.readFile "${inputs.upstream}/scripts/maint/policy.json"
  );
in
{
  imports = [
    inputs.upstream.homeManagerModules.devHeadless
  ];

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

  programs.nushell = {
    loginFile.text = lib.mkForce "";
  };

  home.packages = [
    inputs.yazelix-next.packages.${pkgs.stdenv.hostPlatform.system}.yzn
  ];

  dotfiles.maint = {
    enable = true;
    repo = "/home/ysun/github.com/sctmes/dotfiles";
    host = "116";
    riskMarkers = upstreamMaintPolicy.riskMarkers ++ [
      "docker"
      "containerd"
    ];
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
    settings."github.com" = {
      HostName = "github.com";
      User = "git";
      Port = 22;
      IdentityFile = "~/.ssh/id_ed25519_github";
      IdentitiesOnly = true;
    };
  };

  home.file.".ssh/id_ed25519_github.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRzq7CIHxYsrrUIW5TFFdea1MbYfkWZx6fQQM6ZBiAd ysun@116-github\n";

  services.ssh-agent.enable = true;
}
