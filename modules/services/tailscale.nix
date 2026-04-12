{ inputs, ... }:
{
  rbn.services._.tailscale = {
    darwin =
      { pkgs, ... }:
      {
        services.tailscale = {
          enable = true;
          package = pkgs.tailscale;
        };
      };

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib) mkBefore;
        tailscale0 = config.services.tailscale.interfaceName;
      in
      {
        boot.kernel.sysctl = {
          "net.ipv4.ip_forward" = true;
          "net.ipv6.conf.all.forwarding" = true;
        };

        environment.systemPackages = [ pkgs.tailscale ];

        networking = {
          firewall = {
            allowedUDPPorts = [ config.services.tailscale.port ];
            allowedTCPPorts = [ 5900 ];
            trustedInterfaces = [ tailscale0 ];
            checkReversePath = "loose";
          };

          networkmanager.unmanaged = [ "tailscale0" ];
        };

        services.tailscale = {
          enable = true;
          permitCertUid = "root";
          useRoutingFeatures = "both";
        };

        systemd.network.wait-online.ignoredInterfaces = [ tailscale0 ];

        systemd.services.tailscaled.serviceConfig.Environment = mkBefore [
          "TS_NO_LOGS_SUPPORT=true"
        ];

        sops.secrets."tailscale/key".sopsFile = "${inputs.self}/secrets/secrets.sops.yaml";

        systemd.services.tailscale-autoconnect = {
          enable = true;
          description = "Auto-connect to Tailscale";

          path = with pkgs; [
            tailscale
            jq
          ];

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
            sleep 2
            status="$(tailscale status -json | jq -r .BackendState)"
            if [ $status = "Running" ]; then
              exit 0
            fi
            tailscale up \
              --auth-key "file:${config.sops.secrets."tailscale/key".path}"
          '';
        };
      };
  };
}
