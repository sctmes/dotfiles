{
  config,
  lib,
  pkgs,
  ...
}:
let
  # 固定上游发布的静态二进制，避免在维护时编译 Rust/Cargo 闭包。
  dotlinkBinary = pkgs.stdenvNoCC.mkDerivation {
    pname = "dotlink-bin";
    version = "0.17.1";
    src = pkgs.fetchurl {
      url = "https://github.com/abird-ai/dotlink/releases/download/v0.17.1/dotlink-linux-x86_64";
      name = "dotlink-linux-x86_64-0.17.1";
      hash = "sha256-pG7e0FKbieIV43e4OZDQqJnruj5+PIBH7kbkbebwq2w=";
    };
    dontUnpack = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/dotlink"
      runHook postInstall
    '';
    meta = {
      mainProgram = "dotlink";
      platforms = [ "x86_64-linux" ];
      license = lib.licenses.mit;
    };
  };
in
{
  # 用户已明确确认 unrestricted 模式及 ysun 的持久 root-equivalent 访问。
  services.dotlink = {
    enable = true;
    package = dotlinkBinary;
    user = "ysun";
    workingDirectory = "/home/ysun/dotlink-workspace";
    credentials.runtimeApiKeyFile = "/run/secrets/dotlink-runtime-api-key";
    extraPackages = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.git
    ];
    environment = {
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    settings = {
      transports = {
        openai = true;
        stdio = false;
        http = false;
        ngrok = false;
      };
      tunnel_id = "tunnel_6af2e2f4e8f0819194441ebbe4862fd1";
      organization_id = "org-R8uZrDJtDaS0CPtlgYighlTf";
      permissions = {
        default_allow = false;
        allow_rw = [ "/home/ysun/dotlink-workspace" ];
        allow_shell = true;
        allow_network = true;
      };
    };
  };
  # schema 和 runtime staging 复用上游；保留用户批准的 unrestricted 模式。
  systemd.services.dotlink = lib.mkIf config.services.dotlink.enable {
    path = [
      "/run/wrappers"
      "/etc/profiles/per-user/ysun"
      "/run/current-system/sw"
    ];
    serviceConfig = {
      ExecStart = lib.mkForce "${lib.getExe config.services.dotlink.package} --no-stdio --color=never --unrestricted";
    };
  };
  sops.secrets.dotlink-runtime-api-key = lib.mkIf config.services.dotlink.enable {
    sopsFile = ../../secrets/hosts/116.yaml;
    key = "dotlink-runtime-api-key";
    owner = "ysun";
    mode = "0400";
  };
  systemd.tmpfiles.rules = lib.optionals config.services.dotlink.enable [
    "d /home/ysun/dotlink-workspace 0700 ysun users -"
  ];
}
