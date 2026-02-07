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

        # Setup pg_cron extension and _prisma_migrations table for SplitPro
        # pg_cron requires superuser to create, but we need _prisma_migrations to exist
        # so Prisma doesn't complain about "non-empty schema" when it sees the cron schema
        systemd.services.split-pro-db-setup = {
          description = "Setup pg_cron extension for SplitPro";
          after = [ "postgresql.service" ];
          requires = [ "postgresql.service" ];
          before = [ "split-pro.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [ config.services.postgresql.package ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "postgres";
          };
          script =
            let
              prisma = lib.getExe pkgs.prisma_6;
              splitProDir = "${pkgs.rebellion.split-pro}/share/split-pro";
            in
            ''
              # Create pg_cron extension (requires superuser)
              psql -d ${dbName} -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

              # Create _prisma_migrations table owned by split-pro user
              # This prevents Prisma from seeing the cron schema as "non-empty database"
              psql -d ${dbName} <<EOF
                CREATE TABLE IF NOT EXISTS _prisma_migrations (
                  id VARCHAR(36) PRIMARY KEY,
                  checksum VARCHAR(64) NOT NULL,
                  finished_at TIMESTAMPTZ,
                  migration_name VARCHAR(255) NOT NULL,
                  logs TEXT,
                  rolled_back_at TIMESTAMPTZ,
                  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                  applied_steps_count INTEGER NOT NULL DEFAULT 0
                );
                ALTER TABLE IF EXISTS _prisma_migrations OWNER TO "${dbUser}";

                -- Grant split-pro access to cron schema for the foreign key reference
                GRANT USAGE ON SCHEMA cron TO "${dbUser}";
                GRANT SELECT, REFERENCES ON ALL TABLES IN SCHEMA cron TO "${dbUser}";
              EOF

              # Mark any failed migrations as rolled back so they can be retried
              failed_migrations=$(psql -d ${dbName} -t -A -c "SELECT migration_name FROM _prisma_migrations WHERE finished_at IS NULL AND rolled_back_at IS NULL;")
              for migration in $failed_migrations; do
                echo "Marking failed migration as rolled back: $migration"
                cd ${splitProDir}
                DATABASE_URL="postgresql://${dbUser}@localhost/${dbName}" ${prisma} migrate resolve --rolled-back "$migration"
              done
            '';
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
            port = cfg.port;
            name = "split-pro";
          };
          healthcheck = mk-healthcheck service {
            route = "/";
          };
          authentik-tags = mk-authentik service {
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
