{
  inputs,
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
        "https://cache.nixos.org"
      ]
    }
  '';

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

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

  services.ssh-agent.enable = true;
}
