{
  rbn.programs._.terminal._.devenv.hm =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
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
