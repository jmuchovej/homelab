{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkBefore
    ;

  cfg = config.rebellion.services.tailscale;
in
{
  options.rebellion.services.tailscale = {
    enable = mkEnableOption "tailscale";
  };

  config = mkIf cfg.enable (
    let
      tailscale0 = config.services.tailscale.interfaceName;
    in
    {
      boot.kernel.sysctl = {
        # Enable IP forwarding
        # required for Wireguard & Tailscale/Headscale subnet feature
        # See <https://tailscale.com/kb/1019/subnets/?tab=linux#step-1-install-the-tailscale-client>
        "net.ipv4.ip_forward" = true;
        "net.ipv6.conf.all.forwarding" = true;
      };

      environment.systemPackages = [ pkgs.tailscale ];

      networking = {
        firewall = {
          allowedUDPPorts = [ config.services.tailscale.port ];
          allowedTCPPorts = [ 5900 ];
          trustedInterfaces = [ tailscale0 ];
          # Strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups.
          checkReversePath = "loose";
        };

        networkmanager.unmanaged = [ "tailscale0" ];
      };

      services.tailscale = {
        enable = true;
        permitCertUid = "root";
        useRoutingFeatures = "both";
      };

      systemd.network.wait-online.ignoredInterfaces = [ "${tailscale0}" ];

      systemd.services.tailscaled.serviceConfig.Environment = mkBefore [
        "TS_NO_LOGS_SUPPORT=true"
      ];

      sops.secrets."tailscale/key".sopsFile = lib.snowfall.fs.get-file "secrets/secrets.sops.yaml";

      systemd.services.tailscale-autoconnect = {
        enable = true;

        description = "Auto-connect to Tailscale";

        path = with pkgs; [
          tailscale
          jq
        ];

        # lol. make sure tailscale's running before trying to connect
        after = [
          "network-pre.target"
          "tailscale.service"
        ];
        wants = [
          "network-pre.target"
          "tailscale.service"
        ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig.Type = "oneshot";

        script = ''
          # Wait for `tailscaled` to settle
          sleep 2

          status="$(tailscale status -json | jq -r .BackendState)"
          if [ $status = "Running" ]; then  # All good! Exit.
            exit 0
          fi

          # Otherwise, try authenticating
          tailscale up \
            --auth-key "file:${config.sops.secrets."tailscale/key".path}"
        '';
      };
    }
  );
}
