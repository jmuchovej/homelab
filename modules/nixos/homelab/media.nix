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
      inherit (lib) mkMerge mkIf;
      inherit (lib.rebellion.traefik) mk-service;

      # Check if mesh (Consul) is enabled
      consul-enabled = config.services.mesh.enable or false;

      # Helper to register a service in Consul
      mk-consul-service =
        {
          name,
          port,
          subdomains ? [ ],
          checks ? [ ],
        }:
        {
          service = {
            id = "${name}-${hostname}";
            inherit name port;
            address = config.networking.hostName;

            tags = [
              "traefik.enable=true"
            ]
            ++ (map (sub: "traefik.http.routers.${name}.rule=Host(`${sub}.lab`)") subdomains)
            ++ [
              "traefik.http.services.${name}.loadbalancer.server.port=${toString port}"
            ];

            checks =
              if checks == [ ] then
                [
                  {
                    http = "http://localhost:${toString port}";
                    interval = "10s";
                    timeout = "2s";
                  }
                ]
              else
                checks;

            meta = {
              node = hostname;
            };
          };
        };
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

      # Traefik configuration (existing)
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

      # Consul service registration (when mesh is enabled)
      environment.etc = mkIf consul-enabled {
        "consul.d/plex.json".text = builtins.toJSON (mk-consul-service {
          name = "plex";
          port = 32400;
          subdomains = [
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
        });

        "consul.d/tautulli.json".text = builtins.toJSON (mk-consul-service {
          name = "tautulli";
          port = 8181;
          subdomains = [ "tautulli" ];
          checks = [
            {
              http = "http://localhost:8181/status";
              interval = "10s";
              timeout = "2s";
            }
          ];
        });

        "consul.d/jellyseerr.json".text = builtins.toJSON (mk-consul-service {
          name = "jellyseerr";
          port = 5055;
          subdomains = [
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
        });
      };
    };
}
