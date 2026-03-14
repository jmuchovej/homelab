{
  rbn.cachix.nixos =
    { config, ... }:
    {
      sops.secrets."cachix/token" = { };
      services.cachix-watch-store = {
        enable = true;
        cacheName = "jmuchovej";
        cachixTokenFile = config.sops.secrets."cachix/token".path;
      };
    };
}
