{
  rbn.system._.networking._.manager._.networkmanager.nixos = { lib, pkgs, ... }: {
    networking.networkmanager = {
      enable = true;
      # TODO(jmuchovej): apply this when cutting of to _just_ using NM
      # dns = "dnsmasq";

      # TODO(jmuchovej): apply this when cutting of to _just_ using NM
      # appendNameservers = [
      #   "9.9.9.9"
      #   "149.112.112.112"
      #   "2620:fe::fe"
      #   "2620:fe::9"
      # ];

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

    # TODO(jmuchovej): apply this when cutting of to _just_ using NM
    # environment.etc."NetworkManager/dnsmasq.d/10-rebellion.conf".text = ''
    #   strict-order
    # '';

    # services.resolved.enable = lib.mkForce false;
    # services.dnsmasq.enable = lib.mkForce false;

    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  };
}
