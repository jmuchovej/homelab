{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.s3";
  options =
    { lib, ... }:
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
      inherit (lib.rebellion.file) get-secret;
      inherit (lib.rebellion.network)
        with-consul
        mk-healthcheck
        mk-traefik-service
        mk-authentik
        mk-openid-url
        ;
      inherit (lib.lists) forEach;
      inherit (builtins) toString;

      svc-addr = 9500;
      web-addr = 9501;
      inherit (config.services) minio;
      minio-owner = "minio";
      minio-group = "minio";
    in
    lib.mkMerge [
      (get-secret config "s3/root/user" datacenter)
      (get-secret config "s3/root/pass" datacenter)
      (get-secret config "minio/client-id" "authentik")
      (get-secret config "minio/client-secret" "authentik")
      {
        sops.templates."s3.env" =
          let
            client-id = config.sops.placeholder."minio/client-id";
          in
          {
            content = ''
              MINIO_ROOT_USER=${config.sops.placeholder."s3/root/user"}
              MINIO_ROOT_PASSWORD=${config.sops.placeholder."s3/root/pass"}
              MINIO_IDENTITY_OPENID_CONFIG_URL=${mk-openid-url client-id datacenter}
              MINIO_IDENTITY_OPENID_CLIENT_ID=${client-id}
              MINIO_IDENTITY_OPENID_CLIENT_SECRET=${config.sops.placeholder."minio/client-secret"}
              MINIO_IDENTITY_OPENID_SCOPES="openid profile email entitlements"
            '';
            owner = minio-owner;
            group = minio-group;
            mode = "0400";
          };
        services.minio = {
          enable = true;
          browser = true;
          listenAddress = ":${toString svc-addr}";
          consoleAddress = ":${toString web-addr}";
          rootCredentialsFile = config.sops.templates."s3.env".path;
          region = "us-east-1";
          dataDir = cfg.data-dir;
        };

        systemd.services.minio-init = {
          enable = true;
          path = [
            pkgs.minio
            pkgs.minio-client
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
            User = minio-owner;
            Group = minio-group;
            RuntimeDirectory = "minio-init";
            RuntimeDirectoryMode = "0775";
            EnvironmentFile = [
              minio.rootCredentialsFile
            ];
            # hardening (copied from `minio.nix`)
            DevicePolicy = "closed";
            CapabilityBoundingSet = "";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
              "AF_UNIX"
            ];
            DeviceAllow = "";
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateMounts = true;
            PrivateTmp = true;
            PrivateUsers = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            MemoryDenyWriteExecute = true;
            LockPersonality = true;
            RemoveIPC = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
            ];
            ProtectProc = "invisible";
            ProtectHostname = true;
            UMask = "0077";
            PermissionsStartOnly = true;
          };

          script = ''
            export MC_CONFIG_DIR="$RUNTIME_DIRECTORY"
            sleep 5
            mc alias set minio http://localhost:${toString svc-addr} "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

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
          authentik-tags = mk-authentik service {
            name = "MinIO";
            type = "oauth";
            group = "Compute";
            icon = "minio";
            access = [ "compute-managers" ];
          };
        in
        with-consul config (
          service
          // {
            checks = [
              healthcheck-live
              healthcheck-ready
            ];
            tags = authentik-tags;
          }
        )
      )
    ];
}
