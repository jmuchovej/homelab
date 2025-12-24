{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.traefik";

  options =
    { lib, ... }:
    let
      inherit (lib.rebellion) mkopt-bool;
    in
    {
      consul-integration = mkopt-bool false "Enable Consul Catalog integration for service discovery";
    };

  config =
    {
      cfg,
      config,
      lib,
      ...
    }:
    let
      inherit (lib) mkForce mkIf;
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
        # When consul integration is enabled, ensure consul is running
        after = [ "tailscaled.service" ] ++ lib.options cfg.consul-integration [ "consul.service" ];
        wants = [ "tailscaled.service" ] ++ lib.options cfg.consul-integration [ "consul.service" ];
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

          # Consul Catalog provider for service discovery
          providers = mkIf cfg.consul-integration {
            consulCatalog = {
              endpoint = {
                address = "127.0.0.1:8500";
                scheme = "http";
              };

              # Use Consul Connect for service mesh
              connectAware = true;
              connectByDefault = false;

              # Service name prefix for routing
              prefix = "traefik";

              # Refresh interval
              refreshInterval = "15s";

              # Expose services by default
              exposedByDefault = false;

              # Default rule template (uses service name)
              defaultRule = "Host(`{{ normalize .Name }}.lab`)";

              # Health check configuration
              constraints = "tag==`traefik.enable=true`";
            };
          };
        };
      };

    };
}
