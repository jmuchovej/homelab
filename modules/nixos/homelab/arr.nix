{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.arr";
  config =
    {
      config,
      lib,
      hostname,
      ...
    }:
    let
      inherit (builtins) toString;
      inherit (lib.rebellion.traefik) mk-authd-service with-consul;

      # Helper to generate database permission grants
      mk-db-grants =
        {
          name,
          dbs ? [ ],
        }:
        let
          all-dbs = [
            name
            "${name}-log"
          ]
          ++ dbs;
        in
        lib.concatMapStringsSep "\n" (
          db: ''psql -tAc 'GRANT ALL ON SCHEMA public TO "${name}"' -d ${db}''
        ) all-dbs;

      mk-arr =
        {
          name,
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
            (with-consul config (mk-authd-service {
              inherit hostname name port;
              public = false;
              checks = [
                {
                  http = "http://localhost:${toString port}/ping";
                  interval = "10s";
                  timeout = "2s";
                }
              ];
            }))
          ];
        };

      arrs = map mk-arr [
        {
          port = 7878;
          name = "radarr";
        }
        {
          port = 8989;
          name = "sonarr";
        }
        {
          port = 8686;
          name = "lidarr";
        }
        # { port = 6767; name = "bazarr"; }
        {
          port = 8787;
          name = "readarr";
          dbs = [ "readarr-cache" ];
        }
        {
          port = 9696;
          name = "prowlarr";
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

      ]
      # Individual *arr service configurations
      ++ (map (arr: arr.config) arrs)
    );
}
