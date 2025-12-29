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
    ;

  cfg = config.rebellion.system.networking;
  mesh-enabled = config.rebellion.services.mesh.enable or false;
in
{
  config = mkIf (cfg.enable && cfg.dns == "dnsmasq") {
    networking.networkmanager.dns = "dnsmasq";
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
        }

        # When mesh is enabled, override DNS configuration
        (mkIf mesh-enabled {
          # Forward .consul queries to local Consul agent
          server = [
            "/consul/127.0.0.1#8600"
            # Get default gateway dynamically for other queries
            # This will be the MikroTik router
          ];

          # Listen on all interfaces to serve DNS via VIP
          listen-address = [
            "127.0.0.1"
            "0.0.0.0"
          ];
          bind-interfaces = true;

          # Don't read /etc/resolv.conf for upstream servers
          no-resolv = true;

          # Include the dynamic gateway config when mesh is enabled
          conf-file = [ "/run/dnsmasq/gateway.conf" ];
        })
      ];
    };

    # When mesh is enabled, dynamically set MikroTik as upstream
    systemd.services.dnsmasq-dynamic-upstream = mkIf mesh-enabled {
      description = "Configure dnsmasq to use gateway as upstream DNS";
      wantedBy = [ "dnsmasq.service" ];
      before = [ "dnsmasq.service" ];
      after = [ "network-online.target" ];

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
          # Get the default gateway (MikroTik router)
          GATEWAY=$(${ip} route show default | ${awk} '/default/ { print $3; exit }')

          if [ -n "$GATEWAY" ]; then
            echo "Adding gateway $GATEWAY as upstream DNS for dnsmasq"
            # Create a dnsmasq config snippet
            mkdir -p /run/dnsmasq
            echo "server=$GATEWAY" > /run/dnsmasq/gateway.conf
          else
            echo "Warning: No default gateway found"
            # Fallback to Quad9
            mkdir -p /run/dnsmasq
            echo "server=9.9.9.9" > /run/dnsmasq/gateway.conf
          fi
        '';
    };

    # Open firewall for DNS when mesh is enabled
    networking.firewall = mkIf mesh-enabled {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };

    # Point system DNS to localhost when mesh is enabled
    networking.nameservers = mkIf mesh-enabled (mkForce [ "127.0.0.1" ]);
  };
}
