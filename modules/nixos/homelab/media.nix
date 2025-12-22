{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.media";
  config =
    { lib, hostname, ... }:
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

      services.cloudflared.tunnels."3326fa87-32b9-4693-9c86-3cbe4e735195".ingress = {
        "seerr.jm0.io" = "http://localhost:5055";
        "request.jm0.io" = "http://localhost:5055";
        "requests.jm0.io" = "http://localhost:5055";
      };

      services.traefik.dynamicConfigOptions.http = mkMerge [
        (mk-service {
          inherit hostname;
          name = "plex";
          port = 32400;
          subdomain = [
            "plex"
            "play"
          ];
        })
        (mk-service {
          inherit hostname;
          name = "seerr";
          port = 5055;
          subdomain = [
            "seerr"
            "request"
            "requests"
          ];
        })
      ];
    };
}
