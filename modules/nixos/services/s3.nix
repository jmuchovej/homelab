{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.s3";
  options =
    { lib, pkgs, ... }:
    with lib.types;
    let
      inherit (lib.rebellion) mkopt;
    in
    {
      buckets = mkopt (listOf str) [ "volsync" "postgres" ] "Buckets to create";
      data-dir = mkopt (listOf (either path str)) [
        "/var/lib/minio/data"
      ] "A list of data directories or nodes for storing objects.";
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      hostname,
      datacenter,
      config,
      ...
    }:
    let
      inherit (lib.rebellion.file) get-file;
      inherit (lib.rebellion.network) with-consul mk-healthcheck mk-traefik-service;
      inherit (lib.lists) forEach;
      inherit (builtins) toString;

      svc-addr = 9500;
      web-addr = 9501;
      minio = config.services.minio;
    in
    lib.mkMerge [
      {
        sops.secrets."s3/root/user".sopsFile = get-file "secrets/${datacenter}.sops.yaml";
        sops.secrets."s3/root/pass".sopsFile = get-file "secrets/${datacenter}.sops.yaml";
        sops.templates."S3_ENV" = {
          content = ''
            MINIO_ROOT_USER=${config.sops.placeholders."s3/root/user"}
            MINIO_ROOT_PASSWORD=${config.sops.placeholders."s3/root/pass"}
          '';
          owner = minio.user;
          group = minio.group;
          mode = "0400";
        };
        services.minio = {
          enable = true;
          browser = true;
          listenAddress = ":${toString svc-addr}";
          consoleAddress = ":${toString web-addr}";
          rootCredentialsFile = config.sops.secrets."S3_ENV".path;
          region = "us-east-1";
          dataDir = cfg.data-dir;
        };

        systemd.services.minio-init = {
          enable = true;
          path = with pkgs; [
            minio
            minio-client
          ];
          requiredBy = [ "multi-user.target" ];
          after = [
            "minio.service"
            "consul.service"
          ];
          requires = [
            "minio.service"
            "consul.service"
          ];
          serviceConfig = {
            Type = "simple";
            User = minio.user;
            Group = minio.group;
            RuntimeDirectory = "minio-init";
            EnvironmentFile = [
              minio.rootCredentialsFile
            ];
            Environment = "MC_CONFIG_DIR=$RUNTIME_DIRECTORY";
          };

          script = ''
            set -e
            sleep 5
            mc alias set minio http://s3.services.consul:${toString svc-addr} "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

            # `--region ${minio.region}`
            # `-p`  -- "ignore existing bucket/directory"
            ${toString (forEach cfg.buckets (b: "mc mb --region ${minio.region} -p minio/${b}"))}
          '';
        };
        systemd.services.consul = {
          before = [ "minio-init.service" ];
        };
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            name = "s3";
            port = web-addr;
          };
          healthcheck-live = mk-healthcheck service {
            id = "minio-live";
            route = "/minio/health/live";
          };
          healthcheck-ready = mk-healthcheck service {
            id = "minio-ready";
            route = "/minio/health/ready";
          };
        in
        with-consul config service
        // {
          checks = [
            healthcheck-live
            healthcheck-ready
          ];
        }
      )
    ];
}
