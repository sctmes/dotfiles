{ inputs, username }:

{ ... }:
{
  imports = [
    inputs.upstream.homeManagerModules.headlessDevTools
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    sessionPath = [ "/home/${username}/.local/bin" ];
    stateVersion = "24.11";
  };

  dotfiles.codex = {
    trustedProjects = [
      "/home/${username}/github.com/sctmes/dotfiles"
    ];
    writableRoots = [
      "/home/${username}/.codex/memories"
    ];
  };

  programs.home-manager.enable = true;
}
