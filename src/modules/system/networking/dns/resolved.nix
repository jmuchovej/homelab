_: {
  rbn.system._.networking._.dns._.resolved.nixos =
    { lib, pkgs, ... }:
    let
      inherit (lib) mkForce getExe';
    in
    {
      networking.networkmanager.dns = "systemd-resolved";
      networking.resolvconf.enable = false;

      services.dnsmasq.enable = mkForce false;

      services.resolved = {
        enable = true;

        settings.Resolve = {
          Domains = [
            "lab"
            "~."
          ];
          DNSOverTLS = "opportunistic";
          FallbackDNS = [
            "9.9.9.9"
            "149.112.112.112"
            "2620:fe::fe"
            "2620:fe::9"
          ];
        };
      };

      systemd.services.dynamic-gateway = {
        wantedBy = [ "multi-user.target" ];

        script = mkForce ''
          if [ -f /run/dynamic-gateway/env ]; then
            source /run/dynamic-gateway/env
            echo "Setting DNS to gateway: $GATEWAY on device: $DEVICE"
            ${getExe' pkgs.systemd "resolvectl"} dns "$DEVICE" 127.0.0.1 "$GATEWAY"
          else
            echo "No gateway info found"
            exit 1
          fi
        '';
      };
    };
}
