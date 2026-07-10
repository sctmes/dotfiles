{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  futuOpend = pkgs.callPackage ../../pkgs/futu-opend.nix { };
  accountFile = osConfig.sops.secrets."futu-opend-login-account".path;
  passwordFile = osConfig.sops.secrets."futu-opend-login-password".path;

  launcher = pkgs.writeShellApplication {
    name = "futu-opend-service";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      procps
    ];
    text = ''
      set -eu

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/futu-opend"
      runtime_base="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      runtime_dir="$runtime_base/futu-opend"
      log_dir="$state_dir/log"
      config_file="$runtime_dir/FutuOpenD.xml"

      install -d -m 700 "$state_dir" "$runtime_dir" "$log_dir"

      account_raw="$(tr -d '\r\n' < ${lib.escapeShellArg accountFile})"
      password_raw="$(tr -d '\r\n' < ${lib.escapeShellArg passwordFile})"

      if [ "$account_raw" = "REPLACE_WITH_FUTU_LOGIN_ACCOUNT" ] || \
         [ "$password_raw" = "REPLACE_WITH_FUTU_LOGIN_PASSWORD" ]; then
        echo "Replace futu-opend-login-account and futu-opend-login-password in secrets/hosts/116.yaml first." >&2
        exit 78
      fi

      xml_escape() {
        sed \
          -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
      }

      account="$(printf '%s' "$account_raw" | xml_escape)"
      password="$(printf '%s' "$password_raw" | xml_escape)"

      rm -f "$runtime_dir"/*
      for entry in ${futuOpend}/share/futu-opend/*; do
        name="$(basename "$entry")"
        [ "$name" = FutuOpenD.xml ] && continue
        ln -sfn "$entry" "$runtime_dir/$name"
      done

      umask 077
      cat > "$config_file.tmp" <<EOF
      <futu_opend>
        <ip>127.0.0.1</ip>
        <api_port>11111</api_port>
        <login_account>$account</login_account>
        <login_pwd>$password</login_pwd>
        <lang>chs</lang>
        <log_level>info</log_level>
        <log_path>$log_dir</log_path>
        <push_proto_type>0</push_proto_type>
        <telnet_ip>127.0.0.1</telnet_ip>
        <telnet_port>22222</telnet_port>
        <price_reminder_push>0</price_reminder_push>
        <auto_hold_quote_right>1</auto_hold_quote_right>
      </futu_opend>
      EOF
      mv "$config_file.tmp" "$config_file"

      cd "$runtime_dir"
      exec "$runtime_dir/FutuOpenD" \
        -cfg_file="$config_file" \
        -console=1 \
        -no_monitor=1
    '';
  };
  serviceUnit = pkgs.writeText "futu-opend.service" ''
    [Unit]
    Description=Futu OpenD command line gateway
    After=network-online.target

    [Service]
    ExecStart=${launcher}/bin/futu-opend-service
    Restart=on-failure
    RestartPreventExitStatus=78
    RestartSec=10
  '';
in
{
  home.packages = [ futuOpend ];

  home.file.".config/systemd/user/futu-opend.service".source = serviceUnit;
}
