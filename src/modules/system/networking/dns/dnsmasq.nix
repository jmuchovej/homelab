_: {
  rbn.system._.networking._.dns._.dnsmasq.nixos =
    {
      host,
      config,
      lib,
      ...
    }:
    let
      inherit (lib) mkIf mkForce mkMerge;

      consul =
        host.consul or {
          enable = false;
          dns = {
            enable = false;
          };
        };
      keepalived =
        host.keepalived or {
          enable = false;
          vip = {
            address = "";
          };
          interface = "lo";
        };
      inherit (host) datacenter;
      dynamic-gateway-conf = "/run/dnsmasq/dynamic-gateway.conf";
    in
    {
      networking.networkmanager.dns = mkIf (!(consul.dns.enable or false)) "dnsmasq";
      services.resolved.enable = mkForce false;

      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = true;

        settings = mkMerge [
          {
            strict-order = true;

            server = [
              "9.9.9.9"
              "149.112.112.112"
              "2620:fe::fe"
              "2620:fe::9"
            ];

            interface = [ "lo" ];
            conf-file = [ dynamic-gateway-conf ];
          }

          (mkIf (consul.dns.enable or false) {
            server = [ "/consul/127.0.0.1#8600" ];
            local = [ "/${datacenter}.jm0.io/" ];
            address = [ "/${datacenter}.jm0.io/${keepalived.vip.address}" ];

            interface = [
              "lo"
              keepalived.interface
            ];
          })
        ];
      };

      systemd.services.dynamic-gateway = {
        wantedBy = [ "dnsmasq.target" ];
        before = [ "dnsmasq.target" ];
        requiredBy = [ "dnsmasq.service" ];

        script = mkForce ''
          if [ -f /run/dynamic-gateway/env ]; then
            source /run/dynamic-gateway/env
          else
            echo "No gateway found! Falling back to Quad9."
            export GATEWAY="9.9.9.9"
          fi

          echo "Configuring dnsmasq to use gateway: $GATEWAY"
          mkdir -p "$(dirname "${dynamic-gateway-conf}")"
          echo "server=$GATEWAY" > ${dynamic-gateway-conf}
        '';
      };

      systemd.services.dnsmasq = {
        requires = [ "dynamic-gateway.service" ];
        after = [ "dynamic-gateway.service" ];
      };

      networking.firewall = mkIf (consul.dns.enable or false) {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      };

      networking.nameservers = mkIf (consul.dns.enable or false) (mkForce [ "127.0.0.1" ]);
    };
}
