{ __findFile, inputs, ... }:
{
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types)
        listOf
        str
        either
        path
        ;
    in
    {
      options.s3 = {
        buckets = mkOption {
          type = listOf str;
          default = [ "volsync" ];
          description = "S3 buckets to create on minio-init";
        };
        data-dir = mkOption {
          type = listOf (either path str);
          default = [ "/var/lib/minio/data" ];
          description = "Minio data directories";
        };
      };
    };

  rbn.services._.s3 = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib) concatMapStringsSep;
        inherit (lib.rebellion.network) mk-openid-url;
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";

        svc-addr = 9500;
        web-addr = 9501;
        inherit (config.services) minio;
        minio-owner = "minio";
        minio-group = "minio";

        bucket-cmds = concatMapStringsSep "\n" (
          b: "mc mb --region ${minio.region} -p minio/${b}"
        ) host.s3.buckets;
      in
      {
        sops.secrets."s3/root/user".sopsFile = sops-file datacenter;
        sops.secrets."s3/root/pass".sopsFile = sops-file datacenter;
        sops.secrets."minio/client-id".sopsFile = sops-file "authentik";
        sops.secrets."minio/client-secret".sopsFile = sops-file "authentik";

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
          dataDir = host.s3.data-dir;
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
            EnvironmentFile = [ minio.rootCredentialsFile ];
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
            ${bucket-cmds}
          '';
        };

        systemd.services.consul.before = [ "minio-init.service" ];
      };

    includes = [
      (<rbn/mesh/register> {
        name = "s3";
        port = 9501;
        healthcheck = "/minio/health/live";
        authentik = {
          name = "MinIO";
          type = "oauth";
          group = "Compute";
          icon = "minio";
          access = [ "compute-managers" ];
        };
      })
    ];
  };
}
