{
  inputs,
  ...
}:
{
  imports = [
    inputs.upstream.homeManagerModules.devHeadless
  ];

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

  home.sessionVariables = {
    DOTFILES_MAINT_REPO = "/home/ysun/github.com/sctmes/dotfiles";
    DOTFILES_MAINT_HOST = "116";
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
