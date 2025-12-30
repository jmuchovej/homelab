{
  cfg,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkForce mkMerge;
  inherit (lib.rebellion) disabled;

  mesh = config.rebellion.services.mesh or disabled;
in
mkIf (cfg.dns == "dnsmasq") {
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
      mkdir -p /run/dnsmasq
      echo "server=$GATEWAY" > /run/dnsmasq/gateway.conf
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
