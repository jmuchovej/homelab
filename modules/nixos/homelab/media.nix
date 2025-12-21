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
      users.users.lab.extraGroups = [ "plex" ];

      services.plex = {
        enable = true;
        accelerationDevices = [ "*" ];
        openFirewall = true;
      };

      services.tautulli = {
        enable = true;
        openFirewall = true;
      };

      services.jellyseerr = {
        enable = true;
        openFirewall = true;
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
