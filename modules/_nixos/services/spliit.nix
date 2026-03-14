{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.spliit";
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
        with-consul
        mk-traefik-service
        mk-healthcheck
        ;

      port = 3000;
      dbName = "spliit";
      dbUser = "spliit";
    in
    lib.mkMerge [
      {
        # PostgreSQL database
        services.postgresql = {
          ensureDatabases = [ dbName ];
          ensureUsers = [
            {
              name = dbUser;
              ensureDBOwnership = true;
            }
          ];
        };

        # Spliit systemd service
        systemd.services.spliit = {
          description = "Spliit - Expense Sharing App";
          wantedBy = [ "multi-user.target" ];
          after = [
            "postgresql.service"
            "network.target"
          ];
          wants = [ "postgresql.service" ];

          environment = {
            NODE_ENV = "production";
            PORT = toString port;
            HOSTNAME = "0.0.0.0";
          };

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            User = "spliit";
            Group = "spliit";
            StateDirectory = "spliit";
            WorkingDirectory = "${pkgs.rebellion.spliit}/share/spliit";

            ExecStartPre = "${pkgs.rebellion.spliit}/bin/spliit-migrate";
            ExecStart = "${pkgs.rebellion.spliit}/bin/spliit";

            Restart = "on-failure";
            RestartSec = "5s";

            # Hardening
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;

            EnvironmentFile = config.sops.templates."spliit.env".path;
          };
        };

        sops.templates."spliit.env" = {
          content = ''
            POSTGRES_PRISMA_URL=postgresql://${dbUser}@localhost:${toString config.services.postgresql.settings.port}/${dbName}
            POSTGRES_URL_NON_POOLING=postgresql://${dbUser}@localhost:${toString config.services.postgresql.settings.port}/${dbName}
          '';
        };
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter port;
            name = "spliit";
          };
          healthcheck = mk-healthcheck service {
            route = "/";
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
          }
        )
      )
    ];
}
