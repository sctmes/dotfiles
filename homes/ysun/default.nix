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

  # OpenSSH rejects this machine's Nix-store-backed symlinked user config
  # because store paths are owned by nobody here, so write a real 0600 file.
  home.activation.sshConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    rm -f "$HOME/.ssh/config"
    install -m 600 /dev/stdin "$HOME/.ssh/config" <<'EOF'
  Host github.com
    HostName github.com
    User git
    Port 22
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
  EOF
  '';

  home.file.".ssh/id_ed25519_github.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRzq7CIHxYsrrUIW5TFFdea1MbYfkWZx6fQQM6ZBiAd ysun@116-github\n";

  services.ssh-agent.enable = true;
}
