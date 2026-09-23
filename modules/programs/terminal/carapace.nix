{
  rbn.programs._.terminal._.carapace.hm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.carapace-bridge ];

      programs.carapace = {
        enable = true;
        environment = {
          CARAPACE_MATCH = false;
        };
      };

      mcp-servers.settings.servers = {
        carapace = {
          type = "stdio";
          command = lib.getExe config.programs.carapace.package;
          args = [ "--mcp" ];
        };
      };
    };
}
