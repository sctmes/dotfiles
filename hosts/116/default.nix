{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  githubMcpTokenUsers = [
    username
  ];
  context7ApiKeyUsers = [
    username
  ];

  githubMcpTokenSecretName = user: "github-mcp-token-${user}";
  githubMcpTokenLegacySopsFiles = {
    ysun = ../../secrets/hosts/116.yaml;
  };
  githubMcpTokenSopsFile =
    user:
    githubMcpTokenLegacySopsFiles.${user}
      or (../../secrets/hosts/116 + "/${githubMcpTokenSecretName user}.yaml");
  context7ApiKeySecretName = user: "context7-api-key-${user}";
  context7ApiKeySopsFile = user: ../../secrets/hosts/116 + "/${context7ApiKeySecretName user}.yaml";

  githubMcpTokenSecrets = lib.listToAttrs (
    map (user: {
      name = githubMcpTokenSecretName user;
      value = {
        sopsFile = githubMcpTokenSopsFile user;
        key = "github-mcp-token";
        owner = user;
      };
    }) githubMcpTokenUsers
  );
  context7ApiKeySecrets = lib.listToAttrs (
    map (user: {
      name = context7ApiKeySecretName user;
      value = {
        sopsFile = context7ApiKeySopsFile user;
        key = "context7-api-key";
        owner = user;
        mode = "0400";
      };
    }) context7ApiKeyUsers
  );

  githubMcpTokenHomeUsers = lib.listToAttrs (
    map (user: {
      name = user;
      value.dotfiles.codex.githubTokenFile = config.sops.secrets.${githubMcpTokenSecretName user}.path;
    }) githubMcpTokenUsers
  );
  context7ApiKeyHomeUsers = lib.listToAttrs (
    map (user: {
      name = user;
      value.dotfiles.codex.context7ApiKeyFile = config.sops.secrets.${context7ApiKeySecretName user}.path;
    }) context7ApiKeyUsers
  );
in
{
  imports = [
    ./disko-config.nix
    ./docker.nix
    ./proxy.nix
    ./storage-data1.nix
    ./services.nix
    ./users.nix
  ]
  ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "bigdick";
  networking.useDHCP = false;
  networking.interfaces.enp6s0.useDHCP = true;

  time.timeZone = "Asia/Shanghai";

  programs.nix-ld.enable = true;
  programs.nano.enable = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.swraid.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  sops.defaultSopsFile = ../../secrets/hosts/116.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.secrets = {
    "${username}-password".neededForUsers = true;
    "${username}-github-ssh-key" = {
      owner = username;
      path = "/home/${username}/.ssh/id_ed25519_github";
    };
  }
  // githubMcpTokenSecrets
  // context7ApiKeySecrets;
  home-manager.users = lib.recursiveUpdate githubMcpTokenHomeUsers context7ApiKeyHomeUsers;
  services.openssh.settings = {
    PasswordAuthentication = true;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtt7b+dw26OWbwowudCyFf+HwR6Phh/8pUA0DnA26tV ysun@sctmes-ops"
  ];

  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    docker-compose
    mdadm
    git
    ghostty.terminfo
  ];

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/caddy"
      "/var/lib/docker"
      "/var/lib/ai-serving"
      "/var/lib/label-studio"
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
