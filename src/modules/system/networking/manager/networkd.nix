{
  rbn.system._.networking._.manager._.networkd.nixos = { lib, ... }: {
    networking.useNetworkd = lib.mkForce true;

    systemd.network = {
      enable = true;

      wait-online = {
        enable = false;
        anyInterface = true;
        extraArgs = [ "--ipv4" ];
      };

      networks = {
        "10-dummy" = {
          matchConfig.Name = "dummy*";
          networkConfig = { };
          linkConfig.Unmanaged = "yes";
        };
      };
    };
  };
}
