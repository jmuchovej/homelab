{
  lib,
  __findFile,
  inputs,
  ...
}:
let
  arrs =
    map
      (
        arr:
        arr
        // {
          name = lib.strings.toLower arr.proper-name;
        }
      )
      [
        {
          proper-name = "Radarr";
          port = 7878;
        }
        {
          proper-name = "Sonarr";
          port = 8989;
        }
        {
          proper-name = "Lidarr";
          port = 8686;
        }
        {
          proper-name = "Readarr";
          port = 8787;
          dbs = [ "readarr-cache" ];
        }
        {
          proper-name = "Prowlarr";
          port = 9696;
        }
      ];
in
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
        inherit (lib) mkMerge mkAfter concatMapStringsSep;
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";

        mk-psql =
          {
            name,
            dbs ? [ ],
            ...
          }:
          let
            maindb = name;
            logdb = "${maindb}-log";
            databases = [
              maindb
              logdb
            ]
            ++ dbs;
          in
          {
            inherit databases maindb logdb;
            sql = concatMapStringsSep "\n" (
              db: ''psql -tAc 'GRANT ALL ON SCHEMA public TO "${name}"' -d ${db}''
            ) databases;
          };

        mk-arr =
          {
            name,
            dbs ? [ ],
            ...
          }:
          let
            psql = mk-psql {
              inherit name dbs;
            };
          in
          mkMerge [
            {
              sops.secrets."${name}/key".sopsFile = sops-file datacenter;

              sops.templates."${name}/env".content = ''
                ${lib.toUpper name}__POSTGRES__APIKEY=${config.sops.placeholder."${name}/key"}
              '';

              services.postgresql.ensureDatabases = psql.databases;
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
                  postgres.maindb = psql.maindb;
                  postgres.logdb = psql.logdb;
                };
              };
            }
          ];
      in
      lib.mkMerge (
        [
          {
            systemd.services.postgresql.postStart = mkAfter (
              concatMapStringsSep "\n" (arr: (mk-psql arr).sql) arrs
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
        ++ (map mk-arr arrs)
      );

    includes =
      let
        mk-arr-mesh =
          {
            name,
            proper-name,
            port,
            ...
          }:
          (<rbn/mesh/register> {
            inherit name port;
            authed = true;
            healthcheck = "/ping/";
            authentik = {
              name = proper-name;
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
      map mk-arr-mesh arrs;
  };
}
