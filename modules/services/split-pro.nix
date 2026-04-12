{ __findFile, inputs, ... }:
{
  rbn.services._.split-pro = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib.rebellion.network) mk-openid-url;
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";
        get-sp-exe' = name: lib.getExe' pkgs.rebellion.split-pro "sp-${name}";

        port = 7548;
        db-name = "split-pro";
        db-user = "split-pro";
        psql = config.services.postgresql;
      in
      {
        sops.secrets."mailgun/username".sopsFile = sops-file "secrets";
        sops.secrets."mailgun/smtp-token".sopsFile = sops-file "secrets";
        sops.secrets."split-pro/nextauth-secret".sopsFile = sops-file "secrets";
        sops.secrets."split-pro/client-id".sopsFile = sops-file "authentik";
        sops.secrets."split-pro/client-secret".sopsFile = sops-file "authentik";

        services.postgresql = {
          ensureDatabases = [ db-name ];
          ensureUsers = [
            {
              name = db-user;
              ensureDBOwnership = true;
            }
          ];
          extensions = ps: [ ps.pg_cron ];
          settings = {
            shared_preload_libraries = "pg_cron";
            "cron.database_name" = db-name;
          };
        };

        systemd.services.split-pro-db-setup = {
          description = "Setup database for SplitPro";
          after = [ "postgresql.service" ];
          requires = [ "postgresql.service" ];
          before = [ "split-pro.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "postgres";
            ExecStart = "${get-sp-exe' "db-setup"} ${db-name} ${db-user}";
          };
        };

        systemd.services.split-pro = {
          description = "SplitPro - Expense Sharing App";
          wantedBy = [ "multi-user.target" ];
          after = [
            "postgresql.service"
            "network.target"
            "split-pro-db-setup.service"
          ];
          wants = [ "postgresql.service" ];

          environment = {
            NODE_ENV = "production";
            PORT = toString port;
            HOSTNAME = "0.0.0.0";
            HOME = "%S/%N";
            DATABASE_URL = "postgresql://${db-user}@localhost:${toString psql.settings.port}/${db-name}";
            NEXTAUTH_URL = "https://split-pro.${datacenter}.jm0.io";
            DEFAULT_HOMEPAGE = "/balances";
            DISABLE_EMAIL_SIGNUP = "true";
          };

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            StateDirectory = "split-pro";
            WorkingDirectory = "${pkgs.rebellion.split-pro}/share/split-pro";
            ExecStartPre = get-sp-exe' "migrate";
            ExecStart = get-sp-exe' "server";
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
            EnvironmentFile = config.sops.templates."split-pro.env".path;
          };

          restartTriggers = [ config.sops.templates."split-pro.env".path ];
        };

        sops.templates."split-pro.env" =
          let
            client-id = config.sops.placeholder."split-pro/client-id";
            issuer-url = mk-openid-url client-id datacenter;
          in
          {
            content = ''
              NEXTAUTH_SECRET=${config.sops.placeholder."split-pro/nextauth-secret"}

              OIDC_NAME="The Rebellion"
              OIDC_CLIENT_ID=${client-id}
              OIDC_CLIENT_SECRET=${config.sops.placeholder."split-pro/client-secret"}
              OIDC_WELL_KNOWN_URL=${issuer-url}

              FROM_EMAIL="homelab@jm0.io"
              EMAIL_SERVER_HOST="smtp.mailgun.org"
              EMAIL_SERVER_PORT="587"
              EMAIL_SERVER_USER=${config.sops.placeholder."mailgun/username"}
              EMAIL_SERVER_PASSWORD=${config.sops.placeholder."mailgun/smtp-token"}
            '';
          };
      };

    includes = [
      (<rbn/mesh/register> {
        name = "split-pro";
        port = 7548;
        healthcheck = "/";
        authentik = {
          name = "Split Pro";
          type = "oauth";
          group = "Home";
          access = [ "home" ];
          icon = "di:spliit";
        };
      })
    ];
  };
}
