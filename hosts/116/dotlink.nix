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
    version = "0.14.3";
    src = pkgs.fetchurl {
      url = "https://github.com/abird-ai/dotlink/releases/download/v0.14.3/dotlink-linux-x86_64";
      name = "dotlink-linux-x86_64-0.14.3";
      hash = "sha256-zK75Hz8IbV4OcAM4KGLdE0fqo2wLRMmOvL7pvafM8s0=";
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
  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  # Bubblewrap 会清理父进程环境；工具包装器在沙箱内部设置 CA。
  curlWithCa = (pkgs.writeShellScriptBin "curl" ''
    export CURL_CA_BUNDLE=${caBundle}
    exec ${pkgs.curl}/bin/curl "$@"
  '').overrideAttrs { name = "dotlink-116-curl"; };
  gitWithCa = (pkgs.writeShellScriptBin "git" ''
    export GIT_SSL_CAINFO=${caBundle}
    exec ${pkgs.git}/bin/git "$@"
  '').overrideAttrs { name = "dotlink-116-git"; };
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
    package = dotlinkBinary;
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
