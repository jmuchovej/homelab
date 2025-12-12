{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.rebellion.homelab.authentik;
in
{
  options.rebellion.homelab.authentik = {
    enable = mkEnableOption "authentik";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      authentik
      authentik-outposts.ldap
      authentik-outposts.proxy
    ];

    sops.secrets."authentik".sopsFile = lib.snowfall.fs.get-file "secrets/secrets.sops.yaml";

    services.authentik = {
      enable = true;
      environmentFile = config.sops.secrets.authentik.path;
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

    services.cloudflared = {
      tunnels = {
        "3326fa87-32b9-4693-9c86-3cbe4e735195" = {
          ingress = {
            "id.jm0.io" = "http://localhost:9000";
          };
        };
      };
    };

    services.traefik.dynamicConfigOptions.http = {
      middlewares.authentik.forwardAuth = {
        tls.insecureSkipVerify = true;
        address = "https://localhost:9443/outpost.goauthentik.io/auth/traefik";
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

      services.auth.loadBalancer.servers = [
        { url = "http://localhost:9000"; }
      ];

      routers.auth = {
        entryPoints = [ "websecure" ];
        rule = "Host(`id.jm0.io`) || HostRegexp(`{subdomain:[a-z0-9]+}.lab.jm0.io`) && PathPrefix(`/outpost.goauthentik.io/`)";
        service = "auth";
        tls.certResolver = "letsencrypt";
      };
    };
  };
}
