{ config, lib, ... }@args:
lib.rebellion.mk-module args {
  name = "services.immich";
  config =
    {
      lib,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib.rebellion.file) get-secret' get-secret;
      inherit (lib.rebellion.network)
        mk-openid-url
        with-consul
        mk-healthcheck
        mk-authentik
        mk-traefik-service
        ;
    in
    lib.mkMerge [
      (get-secret config "immich/client-id" "authentik")
      (get-secret config "immich/client-secret" "authentik")
      {
        sops.templates."immich/issuer-url" = {
          content = mk-openid-url config.sops.placeholder."immich/client-id" datacenter;
        };
      }
      {
        services.immich = {
          enable = true;
          host = "0.0.0.0";
          mediaLocation = "/impulse/media/Immich";
          database.enableVectors = false;
          database.enableVectorChord = true;
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
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            port = config.services.immich.port;
            name = "immich";
            subdomain = [
              "immich"
              "photos"
            ];
          };
          healthcheck = mk-healthcheck service {
            route = "/api/server/ping";
          };
          authentik-tags = mk-authentik service {
            type = "oauth";
            group = "Family";
            access = [ "family" ];
            icon = "di:immich";
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

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            port = config.services.immich-public-proxy.port;
            name = "immich-public-proxy";
            subdomain = [
              "immich"
              "photos"
            ];
            route = "/share";
            priority = 20;
          };
          healthcheck = mk-healthcheck service {
            route = "/share/healthceck";
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
            tags = [ ];
          }
        )
      )
    ];
}
