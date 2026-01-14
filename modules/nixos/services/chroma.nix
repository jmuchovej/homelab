{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.chroma";

  config =
    {
      config,
      lib,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib.rebellion) enabled;
      inherit (lib.rebellion.network) mk-traefik-service mk-healthcheck with-consul;
    in
    lib.mkMerge [
      {
        services.chromadb = enabled // {
          host = "localhost";
          port = 24762;
        };
      }
      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            name = "chroma";
            port = config.services.chromadb.port;
          };
          healthcheck = mk-healthcheck service {
            route = "/api/v1/heartbeat";
          };
        in
        with-consul config (service // { check = [ healthcheck ]; })
      )
    ];
}
