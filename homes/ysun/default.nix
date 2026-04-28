{
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.upstream.homeManagerModules.devHeadless
  ];

  xdg.configFile."nix/local-proxy.nuon".text = ''
    {
      HTTP_PROXY: "http://192.168.0.249:7897",
      HTTPS_PROXY: "http://192.168.0.249:7897",
      ALL_PROXY: "http://192.168.0.249:7897",
      NO_PROXY: "127.0.0.1,localhost,internal.domain",
      substituters: [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
      ]
    }
  '';

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

  programs.nushell.loginFile.text = lib.mkForce "";

  home.sessionVariables = {
    DOTFILES_MAINT_REPO = "/home/ysun/github.com/sctmes/dotfiles";
    DOTFILES_MAINT_HOST = "116";
    DOTFILES_MAINT_PROXY_CONFIG = "/home/ysun/.config/nix/local-proxy.nuon";
  };

  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      user.name = "Yu Sun";
      user.email = "ysun@sctmes.com";
    };
  };

  programs.ssh.matchBlocks."github.com" = {
    hostname = "ssh.github.com";
    user = "git";
    port = 443;
    identityFile = "~/.ssh/id_ed25519_github";
    identitiesOnly = true;
  };

  home.file.".ssh/id_ed25519_github.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRzq7CIHxYsrrUIW5TFFdea1MbYfkWZx6fQQM6ZBiAd ysun@116-github\n";

  services.ssh-agent.enable = true;
}
