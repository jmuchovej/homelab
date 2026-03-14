{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "services.homepage";
  options =
    with lib.types;
    let
      inherit (lib.rebellion.options) mk;
    in
    {
      bookmarks = mk (listOf attrs) [ ] "homepage bookmarks";
      services = mk (listOf attrs) [ ] "homepage services";
      settings = mk attrs { } "homepage settings";
      widgets = mk (listOf attrs) [ ] "homepage widgets";
    };

  config =
    {
      cfg,
      config,
      lib,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib.rebellion.network)
        mk-authd-traefik-service
        mk-healthcheck
        with-consul
        mk-authentik
        ;
    in
    lib.mkMerge [
      {
        services.homepage-dashboard = {
          inherit (cfg)
            bookmarks
            services
            settings
            widgets
            ;
          enable = true;
          environmentFile = config.sops.secrets."homepage".path;
          listenPort = 8173;
        };
      }

      (
        let
          service = mk-authd-traefik-service {
            inherit hostname datacenter;
            port = config.services.homepage-dashboard.listenPort;
            name = "homepage";
            subdomain = null;
          };
          healthcheck = mk-healthcheck service {
            route = "/";
          };
          authentik-tags = mk-authentik service {
            name = "Homepage";
            icon = "di:homepage";
            type = "proxy";
            access = [ ];
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
            tags = authentik-tags;
          }
        )
      )
    ];
}
