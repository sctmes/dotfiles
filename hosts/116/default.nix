{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  imports =
    [
      ./disko-config.nix
      ./proxy.nix
      ./storage-data1.nix
      ./services.nix
    ]
    ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "bigdick";
  networking.useDHCP = false;
  networking.interfaces.enp6s0.useDHCP = true;

  time.timeZone = "Asia/Shanghai";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.swraid.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  sops.defaultSopsFile = ../../secrets/hosts/116.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.secrets."${username}-password".neededForUsers = true;
  sops.secrets."${username}-github-ssh-key" = {
    owner = username;
    path = "/home/${username}/.ssh/id_ed25519_github";
  };

  services.openssh.settings = {
    PasswordAuthentication = true;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtt7b+dw26OWbwowudCyFf+HwR6Phh/8pUA0DnA26tV ysun@sctmes-ops"
  ];

  virtualisation.docker.daemon.settings.data-root = "/data1/docker";

  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    docker-compose
    mdadm
    git
  ];

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/sops-nix"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  system.stateVersion = lib.mkForce "24.11";
}
