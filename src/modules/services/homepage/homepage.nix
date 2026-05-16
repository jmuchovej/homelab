{ __findFile, ... }:
{
  rbn.services._.homepage = {
    nixos =
      { config, ... }:
      {
        sops.secrets."homepage" = { };

        services.homepage-dashboard = {
          enable = true;
          environmentFiles = [ config.sops.secrets."homepage".path ];
          listenPort = 8173;
          bookmarks = [ ];
          settings = import ./_settings.nix;
          services = import ./_services.nix;
          widgets = import ./_widgets.nix;
        };
      };

    includes = [
      (<rbn/mesh/register> {
        name = "homepage";
        port = 8173;
        authed = true;
        healthcheck = "/";
        authentik = {
          name = "Homepage";
          icon = "di:homepage";
          type = "proxy";
          group = "Home";
          access = [ ];
        };
      })
    ];
  };
}
