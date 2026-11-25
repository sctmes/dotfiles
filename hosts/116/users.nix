{ pkgs, ... }:

let
  # This command runs with Lucca's privileges, not as root. Fail closed if
  # the mounted volume ACL has not taken effect yet.
  luccaAuthorizedKeys = pkgs.writeShellScript "lucca-authorized-keys" ''
    if ! ${pkgs.util-linux}/bin/mountpoint -q /data1 ||
       test -r /data1 || test -w /data1 || test -x /data1; then
      exit 0
    fi
    exec ${pkgs.coreutils}/bin/cat /etc/ssh/authorized_keys.d/lucca
  '';
in
{
  users.users.zky = {
    isNormalUser = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL26r1M3g+RFbfJZlPpGC/r+MVah2u7X4FbprF9Ekc/d kingz@DESKTOP-G21M0CC"
    ];
  };

  users.users.wangrongfeng = {
    isNormalUser = true;
    shell = pkgs.nushell;
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjIeu5WyAytBPnt/23r7sszhhL5botEl26JNAAEg7Ce ivanwang@sctmes.com"
    ];
  };

  users.users.lucca = {
    isNormalUser = true;
    # /data1's on-disk ACL uses this identity across reinstall.
    uid = 29981;
    group = "lucca";
    shell = pkgs.bashInteractive;
    home = "/home/lucca";
    createHome = true;
    homeMode = "0700";
    hashedPassword = "!";
    extraGroups = [ ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5DPu1EWf0T1qP3CBNRlabgsD+mnM6Ys4TyKucJqwei lucca-yu"
    ];
  };

  users.groups.lucca.gid = 29981;

  # OpenSSH rejects helpers below the group-writable Nix store. Install a
  # regular root-owned file so its resolved path also passes StrictModes.
  environment.etc."ssh/lucca-authorized-keys" = {
    source = luccaAuthorizedKeys;
    mode = "0555";
  };

  services.openssh.extraConfig = ''
    # Keep the existing ingress and SSH settings for other users.
    Match User lucca
      AuthenticationMethods publickey
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      AuthorizedKeysFile none
      AuthorizedKeysCommand /etc/ssh/lucca-authorized-keys
      AuthorizedKeysCommandUser lucca
  '';
}
