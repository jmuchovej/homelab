{ __findFile, ... }:
{
  rbn.services._.n8n = {
    nixos =
      { config, ... }:
      {
        services.n8n = {
          enable = true;
          openFirewall = true;
        };
      };

    includes = [
      (<rbn/mesh/register> {
        name = "n8n";
        port = 5678; # N8N default port
        healthcheck = "/healthz";
      })
    ];
  };
}
