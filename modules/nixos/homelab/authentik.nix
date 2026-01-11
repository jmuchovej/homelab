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
      s3 = config.rebellion.services.s3;

      authentik-host = "https://localhost:94443";

      OUTPOST_ENV = ''
        AUTHENTIK_HOST=${authentik-host}
        AUTHENTIK_HOST_BROWSER=https://id.${datacenter}.jm0.io
        AUTHENTIK_INSECURE=false
      '';
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

        sops.secrets."authentik/outposts/proxy-token".sopsFile = get-file "secrets/secrets.sops.yaml";
        sops.templates."authentik/outposts/proxy-env".content = ''
          AUTHENTIK_TOKEN=${config.sops.placeholder."authentik/outposts/proxy-token"}
          ${OUTPOST_ENV}
        '';

        services.authentik-proxy = enabled // {
          environmentFile = config.sops.templates."authentik/outposts/proxy-env".path;
        };

        sops.secrets."authentik/outposts/ldap-token".sopsFile = get-file "secrets/secrets.sops.yaml";
        sops.templates."authentik/outposts/ldap-env".content = ''
          AUTHENTIK_TOKEN=${config.sops.placeholder."authentik/outposts/proxy-token"}
          ${OUTPOST_ENV}
        '';
        services.authentik-ldap = enabled // {
          environmentFile = config.sops.templates."authentik/outposts/ldap-env".path;
        };

        sops.secrets."authentik/outposts/radius-token".sopsFile = get-file "secrets/secrets.sops.yaml";
        sops.templates."authentik/outposts/radius-env".content = ''
          AUTHENTIK_TOKEN=${config.sops.placeholder."authentik/outposts/radius-token"}
          ${OUTPOST_ENV}
        '';
        services.authentik-radius = enabled // {
          environmentFile = config.sops.templates."authentik/outposts/radius-env".path;
        };

        services.cloudflared.tunnels."3326fa87-32b9-4693-9c86-3cbe4e735195".ingress = {
          "id.jm0.io" = "http://localhost:9000";
        };

        services.traefik.dynamicConfigOptions.http = {
          services.authentik.loadBalancer.servers = [
            { url = "${authentik-host}/outpost.goauthentik.io/"; }
          ];
          middlewares.authentik.forwardAuth = {
            tls.insecureSkipVerify = true;
            address = "${authentik-host}/outpost.goauthentik.io/auth/traefik";
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

      (lib.mkIf s3.enable {
        rebellion.services.s3.buckets = [ "authentik" ];
      })

      (
        let
          inherit (lib.rebellion) merge-attrs;
          inherit (lib.rebellion.network) mk-traefik-service with-consul mk-healthcheck;
          service-base = mk-traefik-service {
            inherit hostname datacenter;
            name = "auth";
            port = 9000;
          };
          inherit (lib.strings) concatStringsSep;
          rule = concatStringsSep " || " [
            "Host(`id.jm0.io`)"
            "Host(`id.${datacenter}.jm0.io`)"
          ];
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
