{
  rbn.networking = {
    provides.static.nixos.networking.tempAddresses = "disabled";
    provides.wol.systemd.network.links."10-wol" = {
      matchConfig.Type = "ether";
      linkConfig.WakeOnLan = "magic";
    };

    nixos.networking = {
      nftables.enable = true;
      wireguard.enable = true;
      firewall.trustedInterfaces = [
        "virbr0"
        "podman0"
        "docker0"
      ];
    };
  };
}
