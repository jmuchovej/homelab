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
      inherit (lib.rebellion.network) mk-traefik-service with-consul mk-healthcheck;
    in
    mkMerge [
      {
        users.users.lab.extraGroups = [ "plex" ];

        services.plex = {
          enable = true;
          accelerationDevices = [ "*" ];
          openFirewall = true;
        };
      }
      (
        let
          service = mk-traefik-service {
            inherit hostname;
            name = "plex";
            port = 32400;
            subdomain = [
              "plex"
              "play"
            ];
          };
          healthcheck = mk-healthcheck service { route = "/web/index.html"; };
        in
        with-consul config (service // { checks = [ healthcheck ]; })
      )
      {
        services.tautulli = {
          enable = true;
          openFirewall = true;
        };
      }
      (
        let
          service = mk-traefik-service {
            inherit hostname;
            name = "tautulli";
            port = 8181;
            public = false;
          };
          healthcheck = mk-healthcheck service { route = "/status"; };
        in
        with-consul config (service // { checks = [ healthcheck ]; })
      )
      {
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
      (
        let
          service = mk-traefik-service {
            inherit hostname;
            name = "seerr";
            port = 5055;
            subdomain = [
              "seerr"
              "request"
              "requests"
            ];
          };
          healthcheck = mk-healthcheck service { route = "/api/v1/status"; };
        in
        with-consul config (service // { checks = [ healthcheck ]; })
      )
    ];
}
