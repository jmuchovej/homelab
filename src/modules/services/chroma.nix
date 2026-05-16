{ __findFile, ... }:
{
  rbn.services._.chroma = {
    nixos = {
      services.chromadb = {
        enable = true;
        host = "localhost";
        port = 24762;
      };
    };

    includes = [
      (<rbn/mesh/register> {
        name = "chroma";
        port = 24762;
        healthcheck = "/api/v2/heartbeat";
      })
    ];
  };
}
