{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.authentik";
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
      inherit (lib.rebellion) enabled;
      inherit (lib.rebellion.file) get-secret get-secret';
      s3 = config.rebellion.services.s3;

      authentik-http = "http://localhost:9000";
      authentik-https = "https://localhost:9443";

      authentik-proxy-http = config.services.authentik-proxy.listenHTTP;
      authentik-proxy-https = config.services.authentik-proxy.listenHTTPS;

      OUTPOST_ENV = ''
        AUTHENTIK_HOST=${authentik-http}
        AUTHENTIK_HOST_BROWSER=https://id.${datacenter}.jm0.io
        AUTHENTIK_INSECURE=false
      '';
    in
    lib.mkMerge [
      (get-secret' config "authentik/secret-key")
      (get-secret' config "authentik/token")
      (get-secret' config "mailgun/smtp-token")
      (get-secret config "outposts/proxy-token" "authentik")
      (get-secret config "outposts/ldap-token" "authentik")
      (get-secret config "outposts/radius-token" "authentik")
      {
        environment.systemPackages = with pkgs; [
          authentik
          authentik-outposts.ldap
          authentik-outposts.proxy
        ];

        # Environment for the main authentik server
        sops.templates."authentik/env".content = ''
          AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik/secret-key"}
          AUTHENTIK_EMAIL__PASSWORD=${config.sops.placeholder."mailgun/smtp-token"}
        '';

        services.authentik = enabled // {
          environmentFile = config.sops.templates."authentik/env".path;
          settings = {
            email = {
              host = "smtp.mailgun.org";
              port = 587;
              username = "postmaster@sandbox99f6437cfdb74594b267f6cc24740684.mailgun.org";
              use_tls = true;
              use_ssl = false;
              from = "homelab@jm0.io";
            };
            disable_startup_analytics = true;
            avatars = "initials";
          };
          worker.listenHTTP = "localhost:9001";
          worker.listenMetrics = "localhost:9301";
        };

        sops.templates."authentik/outposts/proxy-env".content = ''
          AUTHENTIK_TOKEN=${config.sops.placeholder."outposts/proxy-token"}
          ${OUTPOST_ENV}
        '';

        services.authentik-proxy = enabled // {
          environmentFile = config.sops.templates."authentik/outposts/proxy-env".path;
          listenHTTP = "localhost:9004";
          listenHTTPS = "localhost:9005";
          listenMetrics = "localhost:9303";
        };

        # sops.templates."authentik/outposts/ldap-env".content = ''
        #   AUTHENTIK_TOKEN=${config.sops.placeholder."outposts/proxy-token"}
        #   ${OUTPOST_ENV}
        # '';
        # services.authentik-ldap = enabled // {
        #   environmentFile = config.sops.templates."authentik/outposts/ldap-env".path;
        #   listenMetrics = "localhost:9302";
        # };

        # sops.templates."authentik/outposts/radius-env".content = ''
        #   AUTHENTIK_TOKEN=${config.sops.placeholder."outposts/radius-token"}
        #   ${OUTPOST_ENV}
        # '';
        # services.authentik-radius = enabled // {
        #   environmentFile = config.sops.templates."authentik/outposts/radius-env".path;
        #   listenMetrics = "localhost:9306";
        # };

        services.cloudflared.tunnels."3326fa87-32b9-4693-9c86-3cbe4e735195".ingress = {
          "id.jm0.io" = "http://localhost:9000";
        };

        services.traefik.dynamicConfigOptions.http = {
          services.authentik.loadBalancer.servers = [
            { url = "http://${authentik-proxy-http}/outpost.goauthentik.io/"; }
          ];
          middlewares.authentik.forwardAuth = {
            tls.insecureSkipVerify = true;
            address = "http://${authentik-proxy-http}/outpost.goauthentik.io/auth/traefik";
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
