{
  inputs,
  lib,
  ...
}:
let
  proxyConfigPath = "$HOME/.config/nix/local-proxy.nuon";
  defaultProxyConfig = ''
    {
      HTTP_PROXY: "http://127.0.0.1:7890",
      HTTPS_PROXY: "http://127.0.0.1:7890",
      ALL_PROXY: "http://127.0.0.1:7890",
      NO_PROXY: "mirrors.ustc.edu.cn,cache.nixos.org,127.0.0.1,localhost,internal.domain",
      substituters: [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
      ]
    }
  '';
in
{
  imports = [
    inputs.upstream.homeManagerModules.devHeadless
  ];

  home.activation.ensureMutableNixProxyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    proxy_config="${proxyConfigPath}"
    mkdir -p "$(dirname "$proxy_config")"

    if [ -L "$proxy_config" ]; then
      proxy_target="$(readlink -f "$proxy_config" || true)"
      tmp_config="$(mktemp)"
      if [ -n "$proxy_target" ] && [ -f "$proxy_target" ]; then
        cp "$proxy_target" "$tmp_config"
      else
        cat > "$tmp_config" <<'EOF'
${defaultProxyConfig}
EOF
      fi
      rm -f "$proxy_config"
      install -m 0644 "$tmp_config" "$proxy_config"
      rm -f "$tmp_config"
    elif [ ! -e "$proxy_config" ]; then
      cat > "$proxy_config" <<'EOF'
${defaultProxyConfig}
EOF
      chmod 0644 "$proxy_config"
    fi

    # Install-time bootstrap used the operator LAN proxy. Once 116 manages its
    # own Mihomo service, migrate only that exact bootstrap value to localhost.
    if grep -q '192\.168\.0\.249:7897' "$proxy_config"; then
      sed -i 's#http://192\.168\.0\.249:7897#http://127.0.0.1:7890#g' "$proxy_config"
    fi
  '';

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/sctmes/dotfiles"
  ];

  programs.nushell.loginFile.text = lib.mkForce "";

  home.sessionVariables = {
    DOTFILES_MAINT_REPO = "/home/ysun/github.com/sctmes/dotfiles";
    DOTFILES_MAINT_HOST = "116";
    DOTFILES_MAINT_PROXY_CONFIG = "/home/ysun/.config/nix/local-proxy.nuon";
  };

  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      user.name = "Yu Sun";
      user.email = "ysun@sctmes.com";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."github.com" = {
      hostname = "github.com";
      user = "git";
      port = 22;
      identityFile = "~/.ssh/id_ed25519_github";
      identitiesOnly = true;
    };
  };

  home.file.".ssh/id_ed25519_github.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRzq7CIHxYsrrUIW5TFFdea1MbYfkWZx6fQQM6ZBiAd ysun@116-github\n";

  services.ssh-agent.enable = true;
}
