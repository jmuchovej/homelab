{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.media";
  config =
    {
      lib,
      hostname,
      config,
      ...
    }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rebellion.traefik) mk-service with-consul;

    in
    mkMerge [
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
      }
      (with-consul config (mk-service {
        inherit hostname;
        name = "plex";
        port = 32400;
        subdomain = [
          "plex"
          "play"
        ];
        checks = [
          {
            http = "http://localhost:32400/web/index.html";
            interval = "10s";
            timeout = "2s";
          }
        ];
      }))
      (with-consul config (mk-service {
        inherit hostname;
        name = "seerr";
        port = 5055;
        subdomain = [
          "seerr"
          "request"
          "requests"
        ];
        checks = [
          {
            http = "http://localhost:5055/api/v1/status";
            interval = "10s";
            timeout = "2s";
          }
        ];
      }))
      (with-consul config (mk-service {
        inherit hostname;
        name = "tautulli";
        port = 8181;
        public = false;
        checks = [
          {
            http = "http://localhost:8181/status";
            interval = "10s";
            timeout = "2s";
          }
        ];
      }))
    ];
}
