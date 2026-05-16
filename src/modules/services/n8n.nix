{ __findFile, den, ... }:
{
  rbn.services._.n8n = {
    includes = [
      (den.batteries.unfree [ "n8n" ])
      (<rbn/mesh/register> {
        name = "n8n";
        port = 5678; # N8N default port
        healthcheck = "/healthz";
      })
    ];

    nixos =
      { config, ... }:
      {
        services.n8n = {
          enable = true;
          openFirewall = true;
        };
      };
  };
}
