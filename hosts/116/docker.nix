{ config, lib, ... }:

let
  dockerDaemonConfig = config.virtualisation.docker.daemon.settings // {
    registry-mirrors = [ config.sops.placeholder."docker-registry-mirror" ];
  };
in
{
  sops.secrets."docker-registry-mirror" = { };

  sops.templates."docker-daemon.json".content = builtins.toJSON dockerDaemonConfig;

  systemd.services.docker.serviceConfig.ExecStart = lib.mkForce [
    ""
    "${config.virtualisation.docker.package}/bin/dockerd --config-file=${config.sops.templates."docker-daemon.json".path}"
  ];
}
