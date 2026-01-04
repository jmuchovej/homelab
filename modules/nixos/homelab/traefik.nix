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
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib) mkForce mkIf;
      inherit (lib.rebellion) enabled;
      inherit (lib.rebellion.file) get-file;

      data-dir = config.services.traefik.dataDir;
    in
    lib.mkMerge [
      {
        rebellion.security.certificates = enabled;

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        sops.secrets."cloudflare/api-key".sopsFile = get-file "secrets/secrets.sops.yaml";
        sops.templates."CF_DNS_API_TOKEN".content = ''
          CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/api-key"}
        '';

        systemd.services.traefik = {
          serviceConfig.EnvironmentFile = [
            config.sops.templates."CF_DNS_API_TOKEN".path
          ];
          # When consul integration is enabled, ensure consul is running
          after = [ "tailscaled.service" ] ++ lib.optionals cfg.consul-integration [ "consul.service" ];
          wants = [ "tailscaled.service" ] ++ lib.optionals cfg.consul-integration [ "consul.service" ];
        };

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

            api.debug = true;
            api.insecure = true;
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
                      main = "${datacenter}.jm0.io";
                      sans = [ "*.${datacenter}.jm0.io" ];
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

                connectAware = false;

                prefix = "traefik";

                refreshInterval = "15s";

                exposedByDefault = false;
                connectByDefault = false;

                # Default rule template (uses service name)
                defaultRule = "Host(`{{ normalize .Name }}.${datacenter}.jm0.io`)";

                # Health check configuration
                constraints = "Tag(`traefik.enable=true`)";
              };
            };
          };
        };
      }
      (
        let
          inherit (lib.rebellion) merge-attrs;
          inherit (lib.rebellion.network) mk-traefik-service mk-healthcheck with-consul;
          service-base = mk-traefik-service {
            inherit hostname datacenter;
            name = "traefik";
            port = 8080;
          };

          inherit (lib.strings) concatStringsSep;
          rule = concatStringsSep " && " [
            "Host(`${datacenter}.jm0.io`)"
            "(PathPrefix(`/api`) || PathPrefix(`/dashboard`))"
          ];
          service = merge-attrs [
            service-base
            {
              pub.config.rule = rule;
            }
          ];
          healthcheck-api = mk-healthcheck service {
            route = "/api/version";
          };
          healthcheck-dashboard = mk-healthcheck service {
            route = "/dashboard/";
          };
        in
        with-consul config (
          service
          // {
            checks = [
              healthcheck-api
              healthcheck-dashboard
            ];
          }
        )
      )
    ];
}
