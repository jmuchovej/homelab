{
  rbn.services._.cachix.nixos =
    { config, lib, ... }:
    lib.mkMerge [
      (lib.rbn.get-secret' config "cachix/token")
      {
        services.cachix-watch-store = {
          enable = true;
          cacheName = "jmuchovej";
          cachixTokenFile = config.sops.secrets."cachix/token".path;
        };
      }
    ];
}
