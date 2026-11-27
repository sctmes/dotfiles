{ pkgs, ... }:
let
  rules = pkgs.writeText "lucca-tailscale-ingress.nft" ''
    destroy table inet lucca_tailscale_ingress
    table inet lucca_tailscale_ingress {
      chain input {
        type filter hook input priority -20; policy accept;
        iifname "tailscale0" ip saddr 100.101.39.43 tcp dport 22 counter accept
        iifname "tailscale0" ip6 saddr fd7a:115c:a1e0::213a:272c tcp dport 22 counter accept
        iifname "tailscale0" counter drop
      }
      chain forward {
        type filter hook forward priority -20; policy accept;
        iifname "tailscale0" counter drop
      }
    }
  '';
  apply = "${pkgs.nftables}/bin/nft -f ${rules}";
in
{
  # Load before the daemon on boot. Keep this table separate from Docker and
  # Tailscale's tables; replacing it is one atomic nft transaction.
  systemd.services.lucca-tailscale-ingress = {
    description = "Restrict 116 Tailscale ingress to Lucca's workstation SSH";
    requiredBy = [ "tailscaled.service" ];
    before = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    reloadIfChanged = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = apply;
      ExecReload = apply;
    };
  };
}
