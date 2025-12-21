{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.traefik";
  config =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkForce;
      inherit (lib.generators) toYAML;
      inherit (lib.rebellion) enabled;
      inherit (lib.rebellion.file) get-file;

      data-dir = config.services.traefik.dataDir;
    in
    {
      rebellion.security.certificates = enabled;

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      systemd.services.traefik = {
        serviceConfig.EnvironmentFile = [
          config.sops.secrets."cloudflare/api-key".path
        ];
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
      };

      sops.secrets."cloudflare/api-key".sopsFile = get-file "secrets/secrets.sops.yaml";

      services.tailscale.permitCertUid = mkForce "traefik";

      services.traefik = {
        enable = true;

        dynamicConfigOptions = {
          # TLS certificates for local .lab domains
          tls.certificates = [
            {
              certFile = config.sops.secrets."certs/lab.crt".path;
              keyFile = config.sops.secrets."certs/lab.key".path;
            }
          ];
        };

        staticConfigOptions = {
          log = {
            level = "INFO";
            filePath = "${data-dir}/traefik.log";
            format = "json";
            noColor = false;
            maxSize = 100;
            compress = true;
          };

          metrics.prometheus = { };

          tracing = { };

          accessLog = {
            addInternals = true;
            filePath = "${data-dir}/traefik-access.log";
            bufferingSize = 100;
            fields = {
              names = {
                StartUTC = "drop";
              };
            };
            filters.statusCodes = [
              "204-299"
              "400-499"
              "500-599"
            ];
          };

          api.dashboard = true;

          certificatesResolvers = {
            tailscale.tailscale = { };
            letsencrypt = {
              acme = {
                email = "homelab@jm0.io";
                storage = "${data-dir}/acme.json";
                dnsChallenge.provider = "cloudflare";
              };
            };
          };

          entryPoints = {
            redis.address = "0.0.0.0:6381";
            postgres.address = "0.0.0.0:5433";
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
              transport = {
                respondingTimeouts = {
                  readTimeout = "10m";
                  writeTimeout = "10m";
                  idleTimeout = "10m";
                };
              };
            };
          };
        };
      };
    };
}
