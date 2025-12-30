{
  cfg,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkForce getExe';
in
mkIf (cfg.dns == "systemd-resolved") {
  networking.networkmanager.dns = "systemd-resolved";
  networking.resolveconf.enable = false;

  services.dnsmasq.enable = mkForce false;

  services.resolved = {
    enable = true;

    # dnssec = "true";
    # this is necessary to get tailscale picking up your headscale instance
    # and allows you to ping connected hosts by hostname
    domains = [
      "lab"
      "~."
    ];
    dnsovertls = "opportunistic";
    # extraConfig =
    #   mkIf cfg.dns == "dnsmasq" ''
    #     DNSStubListener=false
    #   '';
    fallbackDns = [
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
  };

  systemd.services.dynamic-gateway = {
    wantedBy = [ "multi-user.target" ];

    script = mkForce ''
      # Source the discovered gateway
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
}
