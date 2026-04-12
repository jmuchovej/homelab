{ __findFile, ... }:
{
  rbn.services._.spliit = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        port = 3000;
        dbName = "spliit";
        dbUser = "spliit";
      in
      {
        services.postgresql = {
          ensureDatabases = [ dbName ];
          ensureUsers = [
            {
              name = dbUser;
              ensureDBOwnership = true;
            }
          ];
        };

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

        sops.templates."spliit.env".content = ''
          POSTGRES_PRISMA_URL=postgresql://${dbUser}@localhost:${toString config.services.postgresql.settings.port}/${dbName}
          POSTGRES_URL_NON_POOLING=postgresql://${dbUser}@localhost:${toString config.services.postgresql.settings.port}/${dbName}
        '';
      };

    includes = [
      (<rbn/mesh/register> {
        name = "spliit";
        port = 3000;
        healthcheck = "/";
      })
    ];
  };
}
