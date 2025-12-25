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

      arrs = [
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

      mkarr =
        {
          name,
          port,
          dbs ? [ ],
        }:
        lib.mkMerge [
          {
            sops.secrets."${name}/env".sopsFile = ./arr.sops.yaml;

            services.postgresql.ensureDatabases = [
              name
              "${name}-log"
            ]
            ++ dbs;
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
    in
    lib.mkMerge [
      # PostgreSQL permissions for all *arr apps
      {
        systemd.services.postgresql.postStart = lib.mkAfter (
          lib.concatMapStringsSep "\n" (app: ''
            psql -tAc 'GRANT ALL ON SCHEMA public TO "${app.name}"' -d ${app.name}
            psql -tAc 'GRANT ALL ON SCHEMA public TO "${app.name}"' -d ${app.name}-log
          '') arrs
        );
      }

      # Individual *arr service configurations
      (lib.mkMerge (map mkarr arrs))
    ];
}
