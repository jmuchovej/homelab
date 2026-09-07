{
  rbn.programs._.terminal._.devenv.hm =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      programs.secretspec = {
        enable = true;
        package = pkgs.secretspec;

        settings = {
          defaults = {
            provider = "1password";
            profile = "development";
            providers = {
              "1password" = "onepassword://";
              sops = "sops://";
              dotenv = "dotenv://";
            };
          };
        };
      };

      programs.devenv = {
        enable = true;
        package = pkgs.devenv;
      };

      mcp-servers.settings.servers = {
        devenv = {
          type = "stdio";
          command = lib.getExe config.programs.devenv.package;
          args = [ "mcp" ];
        };
      };
    };
}
