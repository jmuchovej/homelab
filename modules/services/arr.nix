{ __findFile, inputs, ... }:
{
  rbn.services._.arr = {
    nixos =
      {
        host,
        config,
        lib,
        ...
      }:
      let
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";

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
            maindb = name;
            logdb = "${name}-log";
            databases = [
              maindb
              logdb
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
                sops.secrets."${name}/key".sopsFile = sops-file datacenter;

                sops.templates."${name}/env".content = ''
                  ${lib.toUpper name}__POSTGRES__APIKEY=${config.sops.placeholder."${name}/key"}
                '';

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
                  environmentFiles = [ config.sops.templates."${name}/env".path ];
                  settings = {
                    auth.method = "External";
                    postgres.user = name;
                    postgres.host = "localhost";
                    postgres.maindb = maindb;
                    postgres.logdb = logdb;
                  };
                };
              }
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
              configuration = {
                radarr = [ ];
                sonarr = [ ];
              };
            };
          }
        ]
        ++ (map (arr: arr.config) arrs)
      );

    includes =
      let
        mk-arr-mesh =
          { name, port }:
          (<rbn/mesh/register> {
            inherit name port;
            authed = true;
            healthcheck = "/ping/";
            authentik = {
              type = "proxy";
              group = "Media Management";
              access = [ "media-managers" ];
              skip-paths = "/api/*";
              basic-auth = {
                username = "servarr-username";
                password = "servarr-password";
              };
            };
          });
      in
      [
        (mk-arr-mesh {
          name = "radarr";
          port = 7878;
        })
        (mk-arr-mesh {
          name = "sonarr";
          port = 8989;
        })
        (mk-arr-mesh {
          name = "lidarr";
          port = 8686;
        })
        (mk-arr-mesh {
          name = "readarr";
          port = 8787;
        })
        (mk-arr-mesh {
          name = "prowlarr";
          port = 9696;
        })
      ];
  };
}
