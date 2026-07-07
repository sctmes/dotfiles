{
  lib,
  pkgs,
  username,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Orca SSH relay needs Node.js plus node-gyp native build tools on the remote host.
    nodejs_24
    gnumake
    gcc
    python3Minimal
  ];

  users.users = {
    # Workaround for Orca SSH relay bootstrap assuming POSIX login-shell
    # semantics on the remote host. Nushell remains installed, but these Orca
    # target users need bash until upstream handles non-POSIX login shells.
    # https://github.com/stablyai/orca/issues/7715
    ${username}.shell = lib.mkForce pkgs.bashInteractive;
    zky.shell = lib.mkForce pkgs.bashInteractive;
  };
}
