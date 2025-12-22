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
      inherit (lib.rebellion) get-file;
      inherit (lib.rebellion.traefik) mk-authd-service;

      mkarr =
        { name, port }:
        {
          sops.secrets."${name}/env".sopsFile = ./arr.sops.yaml;

          services.postgresql.ensureDatabases = [ name ];
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

          services.traefik.dynamicConfigOptions.http = lib.mkMerge [
            (mk-authd-service { inherit hostname name port; })
          ];
        };
    in
    lib.mkMerge [
      (mkarr {
        port = 7878;
        name = "radarr";
      })
      (mkarr {
        port = 8989;
        name = "sonarr";
      })
      (mkarr {
        port = 8686;
        name = "lidarr";
      })
      # (mkarr { port = 6767; name = "bazarr"; })
      (mkarr {
        port = 8787;
        name = "readarr";
      })
      (mkarr {
        port = 9696;
        name = "prowlarr";
      })
    ];
}
