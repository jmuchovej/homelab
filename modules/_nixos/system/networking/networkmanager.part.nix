{
  cfg,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf optionals;
in
mkIf (cfg.manager == "networkmanager") {
  rebellion.user.extra.groups = [ "networkmanager" ];

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
        inherit (config.rebellion.services) tailscale;
        virt = config.rebellion.virtualization;
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
}
