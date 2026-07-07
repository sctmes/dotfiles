{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Orca SSH relay needs Node.js plus node-gyp native build tools on the remote host.
    nodejs_24
    gnumake
    gcc
    python3Minimal
  ];
}
