{ config, lib, ... }:

let
  dockerDaemonConfig = config.virtualisation.docker.daemon.settings // {
    registry-mirrors = [
      config.sops.placeholder."docker-registry-mirror-dockerhub"
      config.sops.placeholder."docker-registry-mirror-dockerhub-staging"
    ];
  };
in
{
  sops.secrets."docker-registry-mirror-dockerhub" = { };
  sops.secrets."docker-registry-mirror-dockerhub-staging" = { };
  sops.secrets."docker-registry-host-quay" = { };
  sops.secrets."docker-registry-host-gcr" = { };
  sops.secrets."docker-registry-host-k8s-gcr" = { };
  sops.secrets."docker-registry-host-k8s" = { };
  sops.secrets."docker-registry-host-ghcr" = { };
  sops.secrets."docker-registry-host-cloudsmith" = { };
  sops.secrets."docker-registry-host-ecr" = { };

  sops.templates."docker-daemon.json".content = builtins.toJSON dockerDaemonConfig;

  systemd.services.docker.serviceConfig.ExecStart = lib.mkForce [
    ""
    "${config.virtualisation.docker.package}/bin/dockerd --config-file=${config.sops.templates."docker-daemon.json".path}"
  ];
}
