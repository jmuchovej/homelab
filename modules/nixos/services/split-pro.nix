{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.split-pro";
  options =
    let
      inherit (lib) mkopt' types;
    in
    {
      port = mkopt' types.port 3000;
    };
  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib.rebellion.file) get-secret get-secret';
      inherit (lib.rebellion.network)
        with-consul
        mk-traefik-service
        mk-healthcheck
        mk-authentik
        mk-openid-url
        ;

      dbName = "split-pro";
      dbUser = "split-pro";
    in
    lib.mkMerge [
      # Secrets
      (get-secret' config "mailgun/username")
      (get-secret' config "mailgun/smtp-token")
      (get-secret' config "split-pro/nextauth-secret")
      (get-secret config "split-pro/client-id" "authentik")
      (get-secret config "split-pro/client-secret" "authentik")

      {
        # PostgreSQL database with pg_cron extension for scheduled jobs
        services.postgresql = {
          ensureDatabases = [ dbName ];
          ensureUsers = [
            {
              name = dbUser;
              ensureDBOwnership = true;
            }
          ];
          # pg_cron is required for SplitPro's recurring expense feature
          extensions = ps: [ ps.pg_cron ];
          settings = {
            shared_preload_libraries = "pg_cron";
            "cron.database_name" = dbName;
          };
        };

        # Setup pg_cron extension, permissions, and handle failed migrations
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
            ExecStart = "${lib.getExe' pkgs.rebellion.split-pro "sp-db-setup"} ${dbName} ${dbUser}";
          };
        };

        # SplitPro systemd service
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
            PORT = toString cfg.port;
            HOSTNAME = "0.0.0.0";

            # pnpm needs a writable home directory (%S expands to /var/lib)
            HOME = "%S/%N";

            # Database
            DATABASE_URL = "postgresql://${dbUser}@localhost:${toString config.services.postgresql.settings.port}/${dbName}";

            # NextAuth
            NEXTAUTH_URL = "https://split-pro.${datacenter}.jm0.io";

            # Default homepage
            DEFAULT_HOMEPAGE = "/balances";

            # Disable email signup (use Authentik only)
            DISABLE_EMAIL_SIGNUP = "true";

            # Currency rate provider
            # CURRENCY_RATE_PROVIDER = "frankfurter";
          };

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            StateDirectory = "split-pro";
            WorkingDirectory = "${pkgs.rebellion.split-pro}/share/split-pro";

            ExecStartPre = lib.getExe' pkgs.rebellion.split-pro "sp-migrate";
            ExecStart = lib.getExe' pkgs.rebellion.split-pro "sp-server";

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
              # AUTHENTIK_ID=${client-id}
              # AUTHENTIK_SECRET=${config.sops.placeholder."split-pro/client-secret"}
              # AUTHENTIK_ISSUER=${issuer-url}

              FROM_EMAIL="homelab@jm0.io"
              EMAIL_SERVER_HOST="smtp.mailgun.org"
              EMAIL_SERVER_PORT="587"
              EMAIL_SERVER_USER=${config.sops.placeholder."mailgun/username"}
              EMAIL_SERVER_PASSWORD=${config.sops.placeholder."mailgun/smtp-token"}
            '';
          };
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            inherit (cfg) port;
            name = "split-pro";
          };
          healthcheck = mk-healthcheck service {
            route = "/";
          };
          authentik-tags = mk-authentik service {
            name = "Split Pro";
            type = "oauth";
            group = "Home";
            access = [ "home" ];
            icon = "di:spliit"; # Close enough icon
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
            tags = authentik-tags;
          }
        )
      )
    ];
}
