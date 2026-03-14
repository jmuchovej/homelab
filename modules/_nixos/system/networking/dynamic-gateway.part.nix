{
  cfg,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    optionals
    mkDefault
    getExe'
    ;
  inherit (lib.rebellion) disabled;

  mesh = config.rebellion.services.mesh or disabled;
in
{
  systemd.services.discover-gateway = {
    description = "Discover default gateway and network device";
    after = [ "network-online.target" ] ++ optionals mesh.enable [ "consul.service" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script =
      let
        ip = getExe' pkgs.iproute2 "ip";
        awk = getExe' pkgs.gawk "awk";
      in
      ''
        set -euo pipefail

        # Discover gateway and device
        GATEWAY=$(${ip} route show default | ${awk} '/default/ { print $3; exit }')
        DEVICE=$(${ip} route show default | ${awk} '/default/ { print $5; exit }')

        if [ -z "$GATEWAY" ]; then
          echo "Warning: No default gateway found" >&2
          exit 1
        fi

        echo "Discovered gateway: $GATEWAY on device: $DEVICE"

        # Write to runtime directory for other services to source
        mkdir -p /run/dynamic-gateway
        cat > /run/dynamic-gateway/env <<EOF
        GATEWAY=$GATEWAY
        DEVICE=$DEVICE
        EOF

        chmod 644 /run/dynamic-gateway/env
        echo "Wrote gateway info to /run/dynamic-gateway/env"
      '';
  };

  # Base dynamic gateway service - configures DNS using discovered gateway
  # DNS backends (dnsmasq, resolved, etc.) override the script to configure their backend
  systemd.services.dynamic-gateway = {
    description = "Configure DNS to use default gateway";
    after = [
      "network-online.target"
      "discover-gateway.service"
    ]
    ++ optionals mesh.enable [ "consul.service" ];
    wants = [
      "network-online.target"
      "discover-gateway.service"
    ];
    requires = [ "discover-gateway.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    # Default script - DNS backend modules override this via mkForce
    script = mkDefault ''
      echo "No DNS backend configured - dynamic-gateway service should be overridden by dnsmasq.nix or resolved.nix"
      exit 1
    '';
  };

  # Reload service - restarts both discovery and configuration
  systemd.services.dynamic-gateway-reload = {
    description = "Reload dynamic gateway configuration";
    serviceConfig.Type = "oneshot";
    script = ''
      ${getExe' pkgs.systemd "systemctl"} restart discover-gateway.service
      ${getExe' pkgs.systemd "systemctl"} restart dynamic-gateway.service
    '';
  };

  # Trigger on network state changes
  systemd.paths.dynamic-gateway-trigger = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/proc/net/route";
      Unit = "dynamic-gateway-reload.service";
    };
  };
}
