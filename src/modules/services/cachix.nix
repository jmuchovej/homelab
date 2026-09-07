{
  rbn.services._.cachix.nixos =
    { config, lib, ... }:
    lib.mkMerge [
      (lib.rbn.get-secret' "cachix/token")
      {
        services.cachix-watch-store = {
          enable = true;
          cacheName = "jmuchovej";
          cachixTokenFile = config.sops.secrets."cachix/token".path;
        };

        nix.settings = {
          extra-substituters = [ "https://cachix.cachix.org" ];
          extra-trusted-public-keys = [
            "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
          ];
        };
      }
    ];
}
