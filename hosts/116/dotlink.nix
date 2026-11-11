{
  config,
  lib,
  pkgs,
  ...
}:
let
  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  # Bubblewrap 会清理父进程环境；工具包装器在沙箱内部设置 CA。
  curlWithCa = pkgs.writeShellScriptBin "curl" ''
    export CURL_CA_BUNDLE=${caBundle}
    exec ${pkgs.curl}/bin/curl "$@"
  '';
  gitWithCa = pkgs.writeShellScriptBin "git" ''
    export GIT_SSL_CAINFO=${caBundle}
    exec ${pkgs.git}/bin/git "$@"
  '';
  profileFile = pkgs.writeText "dotlink-116-profile.json" (
    builtins.toJSON (
      ({
        transports = {
          openai = true;
          stdio = false;
          http = false;
          ngrok = false;
        };
        # 用户已确认 Personal org 与唯一可选 ChatGPT workspace 关联。
        tunnel_id = "tunnel_6af2e2f4e8f0819194441ebbe4862fd1";
        organization_id = "org-R8uZrDJtDaS0CPtlgYighlTf";
        permissions = {
          default_allow = false;
          allow_rw = [ "/home/ysun/dotlink-workspace" ];
          allow_shell = true;
          allow_network = true;
        };
      })
      // {
        version = 10;
      }
    )
  );
in
{
  # 用户已明确确认 unrestricted 模式及 ysun 的持久 root-equivalent 访问。
  services.dotlink = {
    enable = true;
    user = "ysun";
    workingDirectory = "/home/ysun/dotlink-workspace";
    credentials.runtimeApiKeyFile = "/run/secrets/dotlink-runtime-api-key";
    extraPackages = [
      pkgs.bash
      pkgs.coreutils
      curlWithCa
      gitWithCa
    ];
    environment = {
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    configFile = "/run/dotlink/config.jsonc";
  };
  # 上游 settings 把 profile 放进 /nix/store，会与 shell 的 protected path 检查冲突。
  # 非秘密配置仍声明式生成，启动前复制至独立 runtime 目录；秘密只走 LoadCredential。
  systemd.services.dotlink = lib.mkIf config.services.dotlink.enable {
    path = [ "/run/wrappers" "/etc/profiles/per-user/ysun" "/run/current-system/sw" ];
    serviceConfig = {
      ExecStart = lib.mkForce "${lib.getExe config.services.dotlink.package} --no-stdio --color=never --unrestricted";
      RuntimeDirectory = "dotlink";
      RuntimeDirectoryMode = "0700";
      ExecStartPre = "${pkgs.coreutils}/bin/install -m 0600 ${profileFile} /run/dotlink/config.jsonc";
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
