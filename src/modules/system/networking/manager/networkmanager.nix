_: {
  rbn.system._.networking._.manager._.networkmanager.nixos =
    {
      host,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) optionals;
    in
    {
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

        unmanaged = [
          "interface-name:br-*"
          "interface-name:rndis*"
        ]
        ++ optionals (host.tailscale.enable or false) [ "interface-name:tailscale*" ]
        ++ optionals (host.containers.enable or false) [ "interface-name:docker*" ];
      };

      systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
    };
}
