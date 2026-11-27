{
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.upstream.nixosModules.nixNetwork ];

  nix.settings.extra-substituters = [
    "https://yazelix.cachix.org?priority=60"
  ];

  # Eon 构建按需使用，不加入全机默认 substituters。
  nix.settings.extra-trusted-substituters = [ "https://eon-yazelix.cachix.org" ];

  nix.settings.extra-trusted-public-keys = [
    "eon-yazelix.cachix.org-1:kPIp7u0Gjoz0GNzmRqeaqs798vU2raSOUpK+3xi7oK0="
    "yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM="
  ];

  dotfiles.nixNetwork = {
    profile = "china";
    proxy = {
      enable = true;
      url = "http://127.0.0.1:7890";
    };
    nameservers = [
      "127.0.0.1"
      "192.168.0.1"
    ];
  };

  # The default resolver on 116 is Mihomo (fake-ip). Keep real DNS local to this unit.
  systemd.services.tailscaled = {
    # Use the unit's resolver rather than the host's glibc/nscd cache.
    environment.GODEBUG = "netdns=go";
    serviceConfig = {
      UnsetEnvironment = [
        "HTTP_PROXY"
        "HTTPS_PROXY"
        "ALL_PROXY"
        "NO_PROXY"
        "http_proxy"
        "https_proxy"
        "all_proxy"
        "no_proxy"
      ];
      BindReadOnlyPaths = [
        "${pkgs.writeText "tailscaled-resolv.conf" ''
          nameserver 192.168.0.1
          options timeout:2 attempts:2
        ''}:/etc/resolv.conf"
      ];
    };
  };

  systemd.services.tailscale-direct-routes = {
    description = "Prepare host 116 routes for direct Tailscale egress";
    before = [ "tailscaled.service" ];
    requiredBy = [ "tailscaled.service" ];
    path = [ pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    # Use Tailscale's existing Linux bypass mark, including during startup before
    # tailscaled has installed its own rules. DNS only matches the LAN resolver;
    # every other service keeps its existing system resolver and TUN policy.
    script = ''
      for family in -4 -6; do
        ip "$family" rule list | grep -q '^5209:' && exit 1
      done
      ip -4 rule list | grep -Eq '^(8987|8988):' && exit 1
      trap 'rc=$?; if [ "$rc" -ne 0 ]; then
        ip -4 rule del pref 5209 fwmark 0x80000/0xff0000 lookup main 2>/dev/null || :
        ip -6 rule del pref 5209 fwmark 0x80000/0xff0000 lookup main 2>/dev/null || :
        ip -4 rule del pref 8987 to 192.168.0.1/32 ipproto udp dport 53 lookup main 2>/dev/null || :
        ip -4 rule del pref 8988 to 192.168.0.1/32 ipproto tcp dport 53 lookup main 2>/dev/null || :
      fi; exit "$rc"' EXIT
      ip -4 rule add pref 5209 fwmark 0x80000/0xff0000 lookup main
      ip -6 rule add pref 5209 fwmark 0x80000/0xff0000 lookup main
      ip -4 rule add pref 8987 to 192.168.0.1/32 ipproto udp dport 53 lookup main
      ip -4 rule add pref 8988 to 192.168.0.1/32 ipproto tcp dport 53 lookup main
    '';
    preStop = ''
      ip -4 rule del pref 5209 fwmark 0x80000/0xff0000 lookup main 2>/dev/null || :
      ip -6 rule del pref 5209 fwmark 0x80000/0xff0000 lookup main 2>/dev/null || :
      ip -4 rule del pref 8987 to 192.168.0.1/32 ipproto udp dport 53 lookup main 2>/dev/null || :
      ip -4 rule del pref 8988 to 192.168.0.1/32 ipproto tcp dport 53 lookup main 2>/dev/null || :
    '';
  };
}
