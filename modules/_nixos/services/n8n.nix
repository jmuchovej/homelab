{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "services.n8n";
  config =
    {
      lib,
      hostname,
      datacenter,
      config,
      ...
    }:
    let
      inherit (lib.rebellion.network) mk-traefik-service with-consul;
    in
    lib.mkMerge [
      {
        services.n8n = {
          enable = true;
          openFirewall = true;
        };
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            port = config.services.n8n.environment.N8N_PORT;
            name = "n8n";
          };
        in
        with-consul config service
      )
    ];
}
