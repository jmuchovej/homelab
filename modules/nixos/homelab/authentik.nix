{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.authentik";
  config =
    {
      config,
      pkgs,
      lib,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib.rebellion) get-file enabled;
    in
    lib.mkMerge [
      {
        environment.systemPackages = with pkgs; [
          authentik
          authentik-outposts.ldap
          authentik-outposts.proxy
        ];

        sops.secrets."authentik/secret-key".sopsFile = get-file "secrets/secrets.sops.yaml";
        sops.secrets."authentik/token".sopsFile = get-file "secrets/secrets.sops.yaml";
        sops.secrets."mailgun/token".sopsFile = get-file "secrets/secrets.sops.yaml";

        # Environment for the main authentik server
        sops.templates."AUTHENTIK_ENV".content = ''
          AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik/secret-key"}
          AUTHENTIK_EMAIL__PASSWORD=${config.sops.placeholder."mailgun/token"}
        '';

        # Environment for outposts (proxy, ldap, radius)
        sops.templates."AUTHENTIK_OUTPOST_ENV".content = ''
          AUTHENTIK_HOST=https://id.${datacenter}.jm0.io
          AUTHENTIK_TOKEN=${config.sops.placeholder."authentik/token"}
          AUTHENTIK_INSECURE=false
        '';

        services.authentik = enabled // {
          environmentFile = config.sops.templates."AUTHENTIK_ENV".path;
          settings = {
            email = {
              host = "smtp.mailgun.org";
              port = 587;
              username = "postmaster@sandbox99f6437cfdb74594b267f6cc24740684.mailgun.org";
              use_tls = true;
              use_ssl = false;
              from = "homelab@jm.io";
            };
            disable_startup_analytics = true;
            avatars = "initials";
          };
        };

        services.authentik-proxy = enabled // {
          environmentFile = config.sops.templates."AUTHENTIK_OUTPOST_ENV".path;
        };

        services.authentik-ldap = enabled // {
          environmentFile = config.sops.templates."AUTHENTIK_OUTPOST_ENV".path;
        };

        services.authentik-radius = enabled // {
          environmentFile = config.sops.templates."AUTHENTIK_OUTPOST_ENV".path;
        };

        services.cloudflared.tunnels."3326fa87-32b9-4693-9c86-3cbe4e735195".ingress = {
          "id.jm0.io" = "http://localhost:9000";
        };

        services.traefik.dynamicConfigOptions.http.middlewares = {
          authentik.forwardAuth = {
            tls.insecureSkipVerify = true;
            address = "https://id.${datacenter}.jm0.io/outpost.goauthentik.io/auth/traefik";
            trustForwardHeader = true;
            authResponseHeaders = [
              "X-authentik-username"
              "X-authentik-groups"
              "X-authentik-email"
              "X-authentik-name"
              "X-authentik-uid"
              "X-authentik-jwt"
              "X-authentik-meta-jwks"
              "X-authentik-meta-outpost"
              "X-authentik-meta-provider"
              "X-authentik-meta-app"
              "X-authentik-meta-version"
            ];
          };
        };
      }

      (
        let
          inherit (lib.rebellion) merge-attrs;
          inherit (lib.rebellion.network) mk-traefik-service with-consul mk-healthcheck;
          service-base = mk-traefik-service {
            inherit hostname datacenter;
            name = "auth";
            port = 9000;
          };
          inherit (lib.strings) replaceString concatStringsSep;
          base-rule = concatStringsSep " || " [
            "Host(`id.jm0.io`)"
            "(HostRegexp(`[a-z0-9]+.jm0.io`) && PathPrefix(`/outpost.goauthentik.io/`))"
          ];
          rule = "${base-rule} || ${replaceString "jm0.io" "${datacenter}.jm0.io" base-rule}";
          service = merge-attrs [
            service-base
            {
              pub.config.rule = rule;
            }
          ];
          healthcheck-server = mk-healthcheck service {
            route = "/-/health/ready/";
          };
        in
        with-consul config (service // { checks = [ healthcheck-server ]; })
      )
    ];
}
