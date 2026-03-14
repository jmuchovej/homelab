{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.homepage";
  description = "homepage";
  config =
    {
      cfg,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rebellion.network) mk-authd-traefik-service;
    in
    mkMerge [
      {
        sops.secrets.homepage.sopsFile = ./homepage.sops.yaml;

        services.homepage-dashboard = {
          enable = true;
          environmentFile = config.sops.secrets."homepage".path;
          listenPort = 8173;
          bookmarks = [ ];
          services = import ./services.part.nix;
          settings = import ./settings.part.nix;
          widgets = import ./widgets.part.nix;
        };
      }

      {
        services.traefik.dynamicConfigOptions.http = mk-authd-traefik-service {
          name = "homepage";
          port = 8173;
          subdomain = "";
        };
      }
    ];
}
