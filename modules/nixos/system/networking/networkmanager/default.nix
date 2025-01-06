{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf optionals mkForce;

  cfg = config.${namespace}.system.networking;
in
{
  config = mkIf cfg.enable {
    ${namespace}.user.extra.groups = [ "networkmanager" ];

    networking.networkmanager = {
      enable = true;

      connectionConfig = {
        "connection.mdns" = "2";
      };

      plugins = with pkgs; [
        networkmanager-l2tp
        networkmanager-openvpn
        networkmanager-sstp
        networkmanager-vpnc
      ];

      unmanaged =
        let
          inherit (config.${namespace}.services) tailscale;
          virt = config.${namespace}.virtualization;
        in
        [
          "interface-name:br-*"
          "interface-name:rndis*"
        ]
        ++ optionals tailscale.enable [ "interface-name:tailscale*" ]
        ++ optionals virt.containers.enable [ "interface-name:docker*" ]
        ++ optionals virt.kvm.enable [ "interface-name:virbr*" ];
    };

    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  };
}
