_: {
  rbn.system._.networking._.manager._.networkd.nixos =
    { host, lib, ... }:
    let
      inherit (lib) mkIf mkForce;
    in
    {
      networking.useNetworkd = mkForce true;

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

          "20-tailscale-ignore" = mkIf (host.tailscale.enable or false) {
            matchConfig.Name = "tailscale*";
            linkConfig = {
              Unmanaged = "yes";
              RequiredForOnline = false;
            };
          };
        };
      };
    };
}
