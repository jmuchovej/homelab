{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.homebox";
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
      inherit (lib.rebellion.file) get-secret' get-secret;
      inherit (lib.rebellion.network)
        with-consul
        mk-traefik-service
        mk-healthcheck
        mk-authentik
        mk-openid-url
        ;
    in
    lib.mkMerge [
      (get-secret' config "mailgun/smtp-token")
      (get-secret config "homebox/client-id" "authentik")
      (get-secret config "homebox/client-secret" "authentik")
      {
        services.homebox = {
          enable = true;
          package = pkgs.unstable.homebox;
          settings = {
            HBOX_MODE = "production";

            HBOX_STORAGE_PREFIX_PATH = "/var/lib/homebox/data";

            HBOX_DATABASE_DRIVER = "postgres";
            HBOX_DATABASE_PORT = toString config.services.postgresql.settings.port;
            HBOX_DATABASE_HOST = "localhost";
            HBOX_DATABASE_USERNAME = "homebox";
            HBOX_DATABASE_DATABASE = "homebox";
            HBOX_DATABASE_SSL_MODE = "disable";

            HBOX_OPTIONS_CHECK_GITHUB_RELEASE = "false";

            HBOX_LOG_FORMAT = "json";

            HBOX_MAILER_HOST = "smtp.mailgun.org";
            HBOX_MAILER_PORT = "587";
            HBOX_MAILER_USERNAME = "postmaster@sandbox99f6437cfdb74594b267f6cc24740684.mailgun.org";
            HBOX_MAILER_FROM = "homebox@jm.io";

            HBOX_OIDC_ENABLED = "true";
            HBOX_OIDC_AUTO_REDIRECT = "true";
            HBOX_OIDC_VERIFY_EMAIL = "true";
            HBOX_OIDC_BUTTON_TEXT = "Sign in with JM Cloud";
            HBOX_OIDC_SCOPE = "openid profile email groups";
            HBOX_OIDC_ALLOWED_GROUPS = "Home";

            HBOX_OPTIONS_ALLOW_LOCAL_LOGIN = "false";
            HBOX_OPTIONS_ALLOW_REGISTRATION = "true";
            HBOX_OPTIONS_TRUST_PROXY = "true";
            HBOX_OPTIONS_HOSTNAME = "homebox.${datacenter}.jm0.io";
          };
        };

        sops.templates."homebox.env" =
          let
            inherit (lib) replaceString;
            client-id = config.sops.placeholder."homebox/client-id";
            openid-url = mk-openid-url client-id datacenter;
            issuer-url = replaceString ".well-known/openid-configuration" "" openid-url;
          in
          {
            content = ''
              HBOX_OIDC_CLIENT_ID = ${client-id}
              HBOX_OIDC_ISSUER_URL = ${issuer-url}
              HBOX_OIDC_CLIENT_SECRET = ${config.sops.placeholder."homebox/client-secret"}
              HBOX_MAILER_PASSWORD = ${config.sops.placeholder."mailgun/smtp-token"}
            '';
          };

        systemd.services.homebox = {
          after = [ "postgresql.service" ];
          wants = [ "postgresql.service" ];
          serviceConfig.EnvironmentFile = config.sops.templates."homebox.env".path;
          restartTriggers = [ config.sops.templates."homebox.env".path ];
        };

        services.postgresql = {
          ensureDatabases = [ config.services.homebox.settings.HBOX_DATABASE_DATABASE ];
          ensureUsers = [
            {
              name = config.services.homebox.settings.HBOX_DATABASE_USERNAME;
              ensureDBOwnership = true;
            }
          ];
        };
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            name = "homebox";
            port = 7745;
          };
          healthcheck = mk-healthcheck service {
            route = "/v1/status";
          };
          authentik-tags = mk-authentik service {
            type = "oauth";
            group = "Family";
            access = [ "family" ];
            icon = "di:homebox";
            skip-paths = "/api/*";
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
