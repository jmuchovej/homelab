{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.traefik";
  config =
    { config, lib, ... }:
    let
      inherit (lib) mkForce;
      inherit (lib.rebellion) get-file;
    in
    {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      systemd.services.traefik = {
        environment = {
          CF_API_EMAIL = "homelab@jm0.io";
        };
        serviceConfig = {
          EnvironmentFile = [
            config.sops.secrets."cloudflare/api-key".path
          ];
        };
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
      };

      sops.secrets."cloudflare/api-key".sopsFile = get-file "secrets/secrets.sops.yaml";

      services.tailscale.permitCertUid = mkForce "traefik";

      services.traefik = {
        enable = true;

        staticConfigOptions = {
          log = {
            level = "INFO";
            filePath = "${config.services.traefik.dataDir}/traefik.log";
            format = "json";
            noColor = false;
            maxSize = 100;
            compress = true;
          };

          metrics.prometheus = { };

          tracing = { };

          accessLog = {
            addInternals = true;
            filePath = "${config.services.traefik.dataDir}/traefik-access.log";
            bufferingSize = 100;
            fields = {
              names = {
                StartUTC = "drop";
              };
            };
            filters = {
              statusCodes = [
                "204-299"
                "400-499"
                "500-599"
              ];
            };
          };
          api.dashboard = true;

          certificatesResolvers = {
            tailscale.tailscale = { };
            letsencrypt = {
              acme = {
                email = "homelab@jm0.io";
                storage = "${config.services.traefik.dataDir}/acme.json";
                dnsChallenge = {
                  provider = "cloudflare";
                };
              };
            };
          };

          entryPoints = {
            redis = {
              address = "0.0.0.0:6381";
            };

            postgres = {
              address = "0.0.0.0:5432";
            };

            web = {
              address = "0.0.0.0:80";
              http.redirections.entryPoint = {
                to = "websecure";
                scheme = "https";
                permanent = true;
              };
            };

            websecure = {
              address = "0.0.0.0:443";
              http.tls = {
                certResolver = "letsencrypt";
                domains = [
                  {
                    main = "lab.jm0.io";
                    sans = [ "*.lab.jm0.io" ];
                  }
                  {
                    main = "jm0.io";
                    sans = [ "*.jm0.io" ];
                  }
                ];
              };
            };
          };
        };
      };
    };
}
