{ inputs, username }:

{ ... }:
{
  imports = [
    inputs.upstream.homeManagerModules.shellHeadless
    inputs.upstream.homeManagerModules.tuiHeadless
  ];

  xdg.enable = true;

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    sessionPath = [ "/home/${username}/.local/bin" ];
    stateVersion = "24.11";
  };

  programs.home-manager.enable = true;
  programs.ripgrep.enable = true;
}
