{ inputs, ... }:
{
  rbn.services._.postgres.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      sops.secrets."postgres/terraform".sopsFile = "${inputs.self}/secrets/secrets.sops.yaml";

      sops.templates."init.sql" = {
        content = ''
          CREATE USER terraform WITH PASSWORD '${config.sops.placeholder."postgres/terraform"}';
          CREATE DATABASE terraform;
          GRANT ALL PRIVILEGES ON DATABASE terraform TO terraform;
          ALTER DATABASE terraform OWNER TO terraform;
          \c terraform;
          GRANT ALL ON SCHEMA public TO terraform;
          GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO terraform;
        '';
        owner = "postgres";
      };

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_17;
        authentication = pkgs.lib.mkOverride 10 ''
          # type database DBuser  origin-address auth-method
          local  all      all                    trust
          # ipv4
          host   all      all     127.0.0.1/32   trust
          # ipv6
          host   all      all     ::1/128        trust
        '';
        initialScript = config.sops.templates."init.sql".path;
      };

      services.postgresqlBackup = {
        enable = true;
        backupAll = true;
        startAt = "*-*-* 10:00:00";
      };

      services.traefik.staticConfigOptions.entryPoints.postgres.address = "0.0.0.0:5433";

      services.traefik.dynamicConfigOptions.tcp = {
        services.postgres.loadBalancer.servers = [
          { address = "127.0.0.1:5432"; }
        ];
        routers.postgres = {
          entryPoints = [ "postgres" ];
          rule = "HostSNI(`*`)";
          service = "postgres";
        };
      };
    };
}
