{ __findFile, den, ... }:
{
  rbn.services._.media = {
    nixos = {
      users.users.lab.extraGroups = [ "plex" ];

      services.plex = {
        enable = true;
        accelerationDevices = [ "*" ];
        openFirewall = true;
      };

      services.tautulli = {
        enable = true;
        openFirewall = true;
      };

      services.seerr = {
        enable = true;
        openFirewall = true;
      };

      services.cloudflared.tunnels."3326fa87-32b9-4693-9c86-3cbe4e735195".ingress = {
        "seerr.jm0.io" = "http://localhost:5055";
        "request.jm0.io" = "http://localhost:5055";
        "requests.jm0.io" = "http://localhost:5055";
      };
    };

    includes = [
      (den.provides.unfree [ "plexmediaserver" ])
      (<rbn/mesh/register> {
        name = "plex";
        port = 32400;
        subdomain = [
          "plex"
          "play"
        ];
        healthcheck = "/web/index.html";
      })
      (<rbn/mesh/register> {
        name = "tautulli";
        port = 8181;
        public = false;
        healthcheck = "/status";
      })
      (<rbn/mesh/register> {
        name = "seerr";
        port = 5055;
        subdomain = [
          "seerr"
          "request"
          "requests"
        ];
        healthcheck = "/api/v1/status";
      })
    ];
  };
}
