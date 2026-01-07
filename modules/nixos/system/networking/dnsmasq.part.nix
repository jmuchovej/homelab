{
  cfg,
  config,
  lib,
  datacenter,
  ...
}:
let
  inherit (lib) mkIf mkForce mkMerge;
  inherit (lib.rebellion) disabled;

  mesh = config.rebellion.services.mesh or disabled;
  dynamic-gateway-conf = "/run/dnsmasq/dynamic-gateway.conf";
in
mkIf (cfg.dns == "dnsmasq") {
  networking.networkmanager.dns = mkIf (!mesh.enable) "dnsmasq";
  services.resolved.enable = mkForce false;
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;

    settings = mkMerge [
      {
        # Ensures the gateway is tried first before fallbacks
        strict-order = true;

        # Default upstream servers (Quad9) - these are fallbacks
        server = [
          "9.9.9.9"
          "149.112.112.112"
          "2620:fe::fe"
          "2620:fe::9"
        ];

        interface = [ "lo" ];

        conf-file = [ dynamic-gateway-conf ];
      }

      # When mesh is enabled, add mesh-specific DNS configuration
      (mkIf mesh.enable {
        # Forward .consul queries to local Consul agent
        server = [
          "/consul/127.0.0.1#8600"
        ];

        # The 'local' directive ensures it's authoritative (no upstream query)
        local = [ "/${datacenter}.jm0.io/" ];
        address = [ "/${datacenter}.jm0.io/${mesh.vip.address}" ];

        # Listen on both loopback (for local queries) and mesh interface (for VIP)
        interface = [
          "lo"
          mesh.consul.interface
        ];
      })
    ];
  };

  systemd.services.dynamic-gateway = {
    wantedBy = [ "dnsmasq.target" ];
    before = [ "dnsmasq.target" ];

    script = mkForce ''
      # Source the discovered gateway
      if [ -f /run/dynamic-gateway/env ]; then
        source /run/dynamic-gateway/env
      else
        echo "No gateway found! Falling back to Quad9."
        export GATEWAY="9.9.9.9"  # Quad9
      fi

      echo "Configuring dnsmasq to use gateway: $GATEWAY"
      mkdir -p "$(dirname "${dynamic-gateway-conf}")"
      echo "server=$GATEWAY" > ${dynamic-gateway-conf}
    '';
  };

  # Open firewall for DNS when mesh is enabled
  networking.firewall = mkIf mesh.enable {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };

  # Point system DNS to localhost when mesh is enabled
  networking.nameservers = mkIf mesh.enable (mkForce [ "127.0.0.1" ]);
}
