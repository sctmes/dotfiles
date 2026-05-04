{ pkgs, ... }:

{
  users.users.zky = {
    isNormalUser = true;
    shell = pkgs.nushell;
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
}
