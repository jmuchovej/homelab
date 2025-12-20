{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.media";
  config =
    { lib, ... }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rebellion.traefik) mk-service;
    in
    {
      users.groups.media = {
        name = "media";
        gid = 911;
      };

      services.plex = {
        enable = true;
        accelerationDevices = [ "*" ];
        openFirewall = true;
        dataDir = "/warp/apps/plex";
      };

      services.tautulli = {
        enable = true;
        openFirewall = true;
        dataDir = "/warp/apps/tautulli";
      };

      services.jellyseerr = {
        enable = true;
        openFirewall = true;
        configDir = "/warp/apps/seerr";
      };

      services.traefik.dynamicConfigOptions.http = mkMerge [
        (mk-service {
          name = "plex";
          port = 32400;
          subdomain = [
            "plex"
            "play"
          ];
        })
        (mk-service {
          name = "seerr";
          port = 5055;
          subdomain = [
            "seerr"
            "request"
          ];
        })
      ];
    };
}
