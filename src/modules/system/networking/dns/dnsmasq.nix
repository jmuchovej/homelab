{
  rbn.system._.networking._.dns._.dnsmasq.nixos =
    { lib, ... }:
    let
      dynamic-gateway-conf = "/run/dnsmasq/dynamic-gateway.conf";
    in
    {
      networking.networkmanager.dns = "dnsmasq";
      services.resolved.enable = lib.mkForce false;

      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = true;

        settings = lib.mkMerge [
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
        ];
      };

      systemd.services.dynamic-gateway = {
        wantedBy = [ "dnsmasq.target" ];
        before = [ "dnsmasq.target" ];
        requiredBy = [ "dnsmasq.service" ];

        script = lib.mkForce ''
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
    };
}
