{ __findFile, inputs, ... }:
{
  rbn.services._.immich = {
    nixos =
      {
        host,
        config,
        lib,
        ...
      }:
      let
        inherit (lib.rebellion.network) mk-openid-url;
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";
      in
      {
        sops.secrets."immich/client-id".sopsFile = sops-file "authentik";
        sops.secrets."immich/client-secret".sopsFile = sops-file "authentik";
        sops.secrets."mailgun/username".sopsFile = sops-file "secrets";
        sops.secrets."mailgun/smtp-token".sopsFile = sops-file "secrets";

        sops.templates."immich/issuer-url".content =
          mk-openid-url config.sops.placeholder."immich/client-id"
            datacenter;

        services.immich = {
          enable = true;
          host = "0.0.0.0";
          mediaLocation = "/impulse/media/Immich";
          machine-learning.enable = true;
          settings = {
            oauth = {
              autoLaunch = true;
              autoRegister = true;
              buttonText = "Login with JM Cloud";
              clientId._secret = config.sops.secrets."immich/client-id".path;
              clientSecret._secret = config.sops.secrets."immich/client-secret".path;
              defaultStorageQuota = null;
              enabled = true;
              issuerUrl._secret = config.sops.templates."immich/issuer-url".path;
              mobileOverrideEnabled = false;
              mobileRedirectUri = "";
              profileSigningAlgorithm = "none";
              roleClaim = "immich_role";
              scope = "openid email profile";
              signingAlgorithm = "RS256";
              storageLabelClaim = "preferred_username";
              storageQuotaClaim = "immich_quota";
              timeout = 30000;
              tokenEndpointAuthMethod = "client_secret_post";
            };
            notifications.smtp = {
              enabled = true;
              from = "immich@jm0.io";
              replyTo = "no-reply@jm0.io";
              transport = {
                host = "smtp.mailgun.org";
                port = 587;
                ignoreCert = false;
                secure = false;
                username._secret = config.sops.secrets."mailgun/username".path;
                password._secret = config.sops.secrets."mailgun/smtp-token".path;
              };
            };
            server = {
              externalDomain = "https://photos.${datacenter}.jm0.io";
              loginPageMessage = "";
              publicUsers = false;
            };
            passwordLogin.enabled = false;
            reverseGeocoding.enabled = true;
            storageTemplate = {
              enabled = true;
              hashVerificationEnabled = true;
              template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{fileame}}";
            };
            trash.enabled = true;
            trash.days = 90;
            user.deleteDelay = 7;
          };
        };

        services.immich-public-proxy = {
          enable = true;
          openFirewall = true;
          immichUrl = "http://localhost:${toString config.services.immich.port}";
        };
      };

    includes = [
      (<rbn/mesh/register> {
        name = "immich";
        port = 2283;
        subdomain = [
          "immich"
          "photos"
        ];
        healthcheck = "/api/server/ping";
        authentik = {
          type = "oauth";
          group = "Family";
          access = [ "family" ];
          icon = "di:immich";
          skip-paths = "/api/*";
        };
      })
      (<rbn/mesh/register> {
        name = "immich-public-proxy";
        port = 3000;
        subdomain = [
          "immich"
          "photos"
        ];
        route = "/share";
        priority = 20;
        healthcheck = "/share/healthceck";
      })
    ];
  };
}
