{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.local-llms";
  options =
    { lib, pkgs, ... }:
    with lib.types;
    let
      inherit (lib.rebellion) mkopt mkopt-package;
    in
    {
      ollama = {
        package = mkopt-package pkgs.ollama-cpu "Which version of Ollama should be installed? `pkgs.ollama-[,-vulkan,-rocm,-cuda,-cpu]`";
        models = mkopt (listOf str) [ ] ''
          List of models to download using `ollama pull` once `ollama.service` starts. It generally follows <option>services.ollama.loadModels</option>.

          Search for models on [ollama's library](https://ollama.com/library).
        '';
      };
    };

  config =
    {
      cfg,
      lib,
      config,
      datacenter,
      hostname,
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
    ];
}
