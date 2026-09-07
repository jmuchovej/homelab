{
  rbn.programs._.terminal._.mise.hm = { config, lib, ... }: {
    programs.direnv.mise.enable = false;

    programs.mise = {
      enable = true;
      enableZshIntegration = false;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = false;
      enableMutableConfig = true;
    };

    mcp-servers.settings.servers = {
      mise = {
        command = lib.getExe config.programs.mise.package;
        args = [
          "--cd"
          ""
          "mcp"
        ];
        env = {
          MISE_EXPERIMENTAL = "1";
        };
      };
    };
  };
}
