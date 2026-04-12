{ __findFile, inputs, ... }:
{
  rbn.services._.homebox = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";
      in
      {
        sops.secrets."mailgun/smtp-token".sopsFile = sops-file "secrets";
        sops.secrets."homebox/client-id".sopsFile = sops-file "authentik";
        sops.secrets."homebox/client-secret".sopsFile = sops-file "authentik";

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
            openid-url = <rbn/authentik/openid-url> client-id datacenter;
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
      };

    includes = [
      (<rbn/mesh/register> {
        name = "homebox";
        port = 7745;
        healthcheck = "/v1/status";
        authentik = {
          type = "oauth";
          group = "Family";
          access = [ "family" ];
          icon = "di:homebox";
          skip-paths = "/api/*";
        };
      })
    ];
  };
}
