{ inputs, ... }:
{
  flake-file.inputs = {
    authentik-nix.url = "github:nix-community/authentik-nix";
  };

  den.default.nixos.imports = [
    inputs.authentik-nix.nixosModules.default
  ];

  # OIDC discovery URL helper, reachable as `<rbn/authentik/openid-url>`.
  # Usage: <rbn/authentik/openid-url> "homebox" "da"
  rbn.authentik.provides.openid-url = {
    __functor =
      _self: client-id: datacenter:
      "https://id.${datacenter}.jm0.io/application/o/${client-id}-oauth/.well-known/openid-configuration";
  };

  # ── Aspect ─────────────────────────────────────────────────────────
  rbn.services._.authentik.nixos =
    {
      host,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rbn)
        enabled
        get-secret
        get-secret'
        merge-deep
        mk-traefik-service
        with-consul
        mk-healthcheck
        ;
      inherit (host) hostname datacenter;

      authentik-http = "http://localhost:9000";
      authentik-proxy-http = config.services.authentik-proxy.listenHTTP;

      OUTPOST_ENV = ''
        AUTHENTIK_HOST=${authentik-http}
        AUTHENTIK_HOST_BROWSER=https://id.${datacenter}.jm0.io
        AUTHENTIK_INSECURE=false
        AUTHENTIK_OUTPOST__DISABLE_EMBEDDED_OUTPOST=true
      '';

      # `blueprints_dir` is a single path, so merge authentik's built-in
      # blueprints with our custom ones (e.g. the terraform service account).
      merged-blueprints = pkgs.runCommand "authentik-blueprints" { } ''
        mkdir -p $out
        cp -r ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints/. $out/
        cp ${./tofu-service-account.yaml} $out/tofu-service-account.yaml
      '';
    in

    mkMerge [
      (get-secret' config "authentik/secret-key")
      (get-secret' config "authentik/token")
      (get-secret' config "authentik/admin-password")
      (get-secret' config "authentik/bootstrap-token")
      (get-secret' config "mailgun/smtp-token")
      (get-secret config "outposts/proxy-token" "authentik")
      (get-secret config "outposts/ldap-token" "authentik")
      (get-secret config "outposts/radius-token" "authentik")
      {
        sops.templates."authentik/env".content = ''
          AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik/secret-key"}
          AUTHENTIK_BOOTSTRAP_TOKEN=${config.sops.placeholder."authentik/bootstrap-token"}
          AUTHENTIK_BOOTSTRAP_PASSWORD_HASH=${config.sops.placeholder."authentik/admin-password"}
          AUTHENTIK_TERRAFORM_TOKEN=${config.sops.placeholder."authentik/token"}
          AUTHENTIK_EMAIL__PASSWORD=${config.sops.placeholder."mailgun/smtp-token"}
        '';

        services.authentik = enabled // {
          environmentFile = config.sops.templates."authentik/env".path;
          settings = {
            blueprints_dir = "${merged-blueprints}";
            email = {
              host = "smtp.mailgun.org";
              port = 587;
              username = "postmaster@sandbox99f6437cfdb74594b267f6cc24740684.mailgun.org";
              use_tls = true;
              use_ssl = false;
              from = "homelab@jm0.io";
            };
            outposts.disable_embedded_outpost = true;
            tenants.enabled = true;
            disable_startup_analytics = true;
            avatars = "initials";
          };
          worker.listenHTTP = "127.0.0.1:9001";
          worker.listenMetrics = "127.0.0.1:9301";
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

      # Consul service registration
      (
        let
          service-base = mk-traefik-service {
            inherit hostname datacenter;
            name = "auth";
            port = 9000;
          };
          rule = lib.concatStringsSep " || " [
            "Host(`id.jm0.io`)"
            "Host(`id.${datacenter}.jm0.io`)"
          ];
          service = merge-deep [
            service-base
            { pub.config.rule = rule; }
          ];
          healthcheck-server = mk-healthcheck service {
            route = "/-/health/ready/";
          };
        in
        with-consul config (service // { checks = [ healthcheck-server ]; })
      )
    ];
}
