{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkForce;

  cfg = config.rebellion.system.networking;
in
{
  config = mkIf (cfg.enable && cfg.dns == "systemd-resolved") {
    networking.networkmanager.dns = "systemd-resolved";
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

    systemd.services.dynamic-dns = {
      description = "Set DNS to default gateway";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
      ]
      ++ lib.optionals config.rebellion.services.mesh.enable [ "consul.service" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script =
        let
          ip = lib.getExe' pkgs.iproute2 "ip";
          awk = lib.getExe' pkgs.gawk "awk";
          resolvectl = lib.getExe' pkgs.systemd "resolvectl";
        in
        ''
          # Get the default gateway
          GATEWAY=$(${ip} route show default | ${awk} '/default/ { print $3; exit }')
          DEVICE=$(${ip} route show default | ${awk} '/default/ { print $5; exit }')

          if [ -n "$GATEWAY" ]; then
            echo "Setting DNS to gateway: $GATEWAY"
            ${resolvectl} dns "$DEVICE" 127.0.0.1 "$GATEWAY"
          else
            echo "No default gateway found"
            exit 1
          fi
        '';
    };

    # Run on network changes
    systemd.services.dynamic-dns-reload = {
      description = "Reload DNS on network changes";
      serviceConfig.Type = "oneshot";
      script = "${pkgs.systemd}/bin/systemctl restart dynamic-dns";
    };

    # Trigger on network state changes
    systemd.paths.dynamic-dns-trigger = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "/proc/net/route";
        Unit = "dynamic-dns-reload.service";
      };
    };
  };
}
