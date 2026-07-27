_: {
  rbn.system._.networking._.manager._.networkmanager.nixos =
    {
      lib,
      pkgs,
      ...
    }:
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
        ];
      };

      systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
    };
}
