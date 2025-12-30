{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    mkMerge
    optionals
    ;
  inherit (lib.rebellion) disabled;

  cfg = config.rebellion.system.networking;
  mesh = config.rebellion.services.mesh or disabled;
in
{
  config = mkIf (cfg.enable && cfg.dns == "dnsmasq") {
    networking.networkmanager.dns = mkIf (!mesh.enable) "dnsmasq";
    services.resolved.enable = mkForce false;
    services.dnsmasq = {
      enable = true;

      resolveLocalQueries = true;

      settings = mkMerge [
        {
          # Default upstream servers (Quad9)
          server = [
            "9.9.9.9"
            "149.112.112.112"
            "2620:fe::fe"
            "2620:fe::9"
          ];

          interface = [ "lo" ];

          # Always include dynamic gateway config (populated by dnsmasq-dynamic-upstream)
          conf-file = [ "/run/dnsmasq/gateway.conf" ];
        }

        # When mesh is enabled, override DNS configuration
        (mkIf mesh.enable {
          # Forward .consul queries to local Consul agent
          server = [ "/consul/127.0.0.1#8600" ];

          # Listen on consul's interface to serve DNS via VIP
          interface = [ mesh.consul.interface ];

          # Don't read /etc/resolv.conf for upstream servers
          no-resolv = true;
        })
      ];
    };

    # Dynamically set gateway as upstream DNS (always enabled, not mesh-specific)
    # This mirrors dynamic-dns in resolved.nix - it's a networking safeguard
    systemd.services.dnsmasq-dynamic-upstream = {
      description = "Configure dnsmasq to use gateway as upstream DNS";
      wantedBy = [ "dnsmasq.service" ];
      before = [ "dnsmasq.service" ];
      after = [ "network-online.target" ] ++ optionals mesh.enable [ "consul.service" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script =
        let
          inherit (lib) getExe';
          ip = getExe' pkgs.iproute2 "ip";
          awk = getExe' pkgs.gawk "awk";
        in
        ''
          # Get the default gateway (router)
          GATEWAY=$(${ip} route show default | ${awk} '/default/ { print $3; exit }')

          if [ -n "$GATEWAY" ]; then
            echo "Adding gateway $GATEWAY as upstream DNS for dnsmasq"
            mkdir -p /run/dnsmasq
            echo "server=$GATEWAY" > /run/dnsmasq/gateway.conf
          else
            echo "Warning: No default gateway found, using Quad9 fallback"
            mkdir -p /run/dnsmasq
            echo "server=9.9.9.9" > /run/dnsmasq/gateway.conf
          fi
        '';
    };

    # Open firewall for DNS when mesh is enabled
    networking.firewall = mkIf mesh.enable {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };

    # Point system DNS to localhost when mesh is enabled
    networking.nameservers = mkIf mesh.enable (mkForce [ "127.0.0.1" ]);
  };
}
