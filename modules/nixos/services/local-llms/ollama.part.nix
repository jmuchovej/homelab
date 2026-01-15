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
    with-consul
    mk-authentik
    mk-healthcheck
    ;
  inherit (lib.rebellion) enabled;
in
lib.mkMerge [
  {
    services.ollama = enabled // {
      package = cfg.ollama.package;
      syncModels = true;
      loadModels = cfg.ollama.models;
    };
  }
  (
    let
      service = mk-authd-traefik-service {
        inherit hostname datacenter;
        name = "ollama";
        port = config.services.ollama.port;
      };
      healthcheck = mk-healthcheck service {
        route = "/";
      };
      authentik-tags = mk-authentik service {
        group = "Compute";
        type = "proxy";
        access = [
          "compute"
          "compute-managers"
        ];
      };
    in
    with-consul config (
      service
      // {
        checks = [ healthcheck ];
        tags = authentik-tags;
        address = config.services.ollama.host;
      }
    )
  )
]
