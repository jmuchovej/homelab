{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.redis";
  config =
    {
      config,
      pkgs,
      ...
    }:
    {
      services.redis = {
        package = pkgs.valkey;

        servers.valkey = {
          enable = true;
          openFirewall = true;
          port = 6379;
          bind = "0.0.0.0";
          logLevel = "debug";
        };
      };

      services.traefik.dynamicConfigOptions.tcp = {
        services.redis.loadBalancer = {
          servers = [
            { address = "127.0.0.1:${toString config.services.redis.servers.main.port}"; }
          ];
        };

        routers.redis = {
          entryPoints = [
            "redis"
            "valkey"
          ];
          rule = "HostSNI(`*`)";
          service = "redis";
        };
      };
    };
}
