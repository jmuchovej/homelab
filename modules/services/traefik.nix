_: {
  # ── Host schema: traefik options ───────────────────────────────────
  den.schema.host =
    { lib, ... }:
    {
      options.traefik = {
        enable = lib.mkEnableOption "Traefik reverse proxy";
        consul-catalog = lib.mkEnableOption "Consul Catalog integration";
      };
    };

  # ── Aspect ─────────────────────────────────────────────────────────
  rbn.services._.traefik.nixos =
    {
      host,
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkForce mkIf optionals;
      inherit (lib.rbn)
        get-secret'
        mk-traefik-service
        mk-healthcheck
        with-consul
        merge-deep
        ;
      inherit (host) hostname datacenter;

      cfg = host.traefik;
      data-dir = config.services.traefik.dataDir;
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        (get-secret' config "cloudflare/api-key")
        {
          # certificates included via suite-common → <rbn/certificates>

          networking.firewall.allowedTCPPorts = [
            80
            443
          ];

          sops.templates."traefik.env".content = ''
            CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/api-key"}
          '';

          systemd.services.traefik = {
            serviceConfig.EnvironmentFile = [
              config.sops.templates."traefik.env".path
            ];
            after = [ "tailscaled.service" ] ++ optionals cfg.consul-catalog [ "consul.service" ];
            wants = [ "tailscaled.service" ] ++ optionals cfg.consul-catalog [ "consul.service" ];
          };

          services.tailscale.permitCertUid = mkForce "traefik";

          services.traefik = {
            enable = true;

            dynamicConfigOptions = {
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
                fields.names.StartUTC = "drop";
                filters.statusCodes = [
                  "204-299"
                  "400-499"
                  "500-599"
                ];
              };

              api = {
                debug = true;
                insecure = true;
                dashboard = true;
              };

              certificatesResolvers = {
                tailscale.tailscale = { };
                letsencrypt.acme = {
                  email = "homelab@jm0.io";
                  storage = "${data-dir}/acme.json";
                  dnsChallenge.provider = "cloudflare";
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
                  transport.respondingTimeouts = {
                    readTimeout = "10m";
                    writeTimeout = "10m";
                    idleTimeout = "10m";
                  };
                };
              };

              providers = mkIf cfg.consul-catalog {
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
                  defaultRule = "Host(`{{ normalize .Name }}.${datacenter}.jm0.io`)";
                  constraints = "Tag(`traefik.enable=true`)";
                };
              };
            };
          };
        }

        # Traefik service registration in Consul
        (
          let
            inherit (lib.strings) concatStringsSep;
            service-base = mk-traefik-service {
              inherit hostname datacenter;
              name = "traefik";
              port = 8080;
            };
            rule = concatStringsSep " && " [
              "Host(`${datacenter}.jm0.io`)"
              "(PathPrefix(`/api`) || PathPrefix(`/dashboard`))"
            ];
            service = merge-deep [
              service-base
              { pub.config.rule = rule; }
            ];
            healthcheck-api = mk-healthcheck service {
              id = "traefik-api";
              route = "/api/version";
            };
            healthcheck-dashboard = mk-healthcheck service {
              id = "traefik-dashboard";
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
      ]
    );
}
