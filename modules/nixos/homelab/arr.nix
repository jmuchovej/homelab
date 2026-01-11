{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.arr";
  config =
    {
      config,
      lib,
      pkgs,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib.rebellion.network)
        mk-authd-traefik-service
        mk-authentik
        mk-healthcheck
        with-consul
        ;

      # Helper to generate database permission grants
      mk-db-grants =
        {
          name,
          dbs ? [ ],
        }:
        lib.concatMapStringsSep "\n" (
          db: ''psql -tAc 'GRANT ALL ON SCHEMA public TO "${name}"' -d ${db}''
        ) dbs;

      mk-arr =
        {
          proper-name,
          name ? lib.strings.toLower proper-name,
          port,
          dbs ? [ ],
        }:
        let
          databases = [
            name
            "${name}-log"
          ]
          ++ dbs;
        in
        {
          psql = mk-db-grants {
            inherit name;
            dbs = databases;
          };

          config = lib.mkMerge [
            {
              sops.secrets."${name}/env".sopsFile = ./arr.sops.yaml;

              services.postgresql.ensureDatabases = databases;
              services.postgresql.ensureUsers = [
                {
                  inherit name;
                  ensureDBOwnership = true;
                }
              ];

              services.${name} = {
                enable = true;
                openFirewall = true;
                environmentFiles = [ config.sops.secrets."${name}/env".path ];
              };
            }
            (
              let
                service = mk-authd-traefik-service {
                  inherit
                    hostname
                    datacenter
                    name
                    port
                    ;
                };
                healthcheck = mk-healthcheck service {
                  route = "/ping/";
                };
                authentik-tags = mk-authentik service {
                  type = "proxy";
                  group = "Media Management";
                  access = [ "media-managers" ];
                  skip-paths = "/api/*";
                  basic-auth.username = "servarr-username";
                  basic-auth.password = "servarr-password";
                };
              in
              with-consul config (
                service
                // {
                  checks = [ healthcheck ];
                  tags = authentik-tags;
                }
              )
            )
          ];
        };

      arrs = map mk-arr [
        {
          port = 7878;
          proper-name = "Radarr";
        }
        {
          port = 8989;
          proper-name = "Sonarr";
        }
        {
          port = 8686;
          proper-name = "Lidarr";
        }
        # { port = 6767; proper-name = "Bazarr"; }
        {
          port = 8787;
          proper-name = "Readarr";
          dbs = [ "readarr-cache" ];
        }
        {
          port = 9696;
          proper-name = "Prowlarr";
        }
      ];
    in
    lib.mkMerge (
      [
        # PostgreSQL permissions for all *arr apps (including custom dbs)
        {
          systemd.services.postgresql.postStart = lib.mkAfter (
            lib.concatMapStringsSep "\n" (arr: arr.psql) arrs
          );
        }
        {
          services.recyclarr = {
            enable = true;
            command = "sync";
            schedule = "daily";
            # https://recyclarr.dev/reference/configuration/
            configuration = {
              radarr = [ ];
              sonarr = [ ];
            };
          };
        }
        # {
        #   # FlareSolverr with fixed NUR package (Chromium 126)
        #   # See: https://github.com/NixOS/nixpkgs/issues/332776
        #   # https://github.com/NixOS/nixpkgs/issues/332776#issuecomment-2506433253
        #   services.flaresolverr = {
        #     enable = true;
        #     package = pkgs.nur.repos.xddxdd.flaresolverr-21hsmw;
        #   };
        # }
        # (
        #   let
        #     inherit (lib.rebellion.network) mk-traefik-service mk-healthcheck with-consul;
        #     service = mk-traefik-service {
        #       inherit hostname datacenter;
        #       name = "flaresolverr";
        #       port = config.services.flaresolverr.port;
        #     };
        #     healthcheck = mk-healthcheck service {
        #       route = "/health";
        #     };
        #   in
        #   with-consul config (service // { checks = [ healthcheck ]; })
        # )
      ]
      # Individual *arr service configurations
      ++ (map (arr: arr.config) arrs)
    );
}
