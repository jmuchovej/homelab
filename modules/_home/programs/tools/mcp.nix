{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.mcp";
  options =
    { lib, ... }:
    let
      inherit (lib.types) listOf str;
      inherit (lib.rebellion.options) mk;
    in
    {
      filesystem = {
        directories = mk (listOf str) [ ] "Directories that MCP servers can access.";
      };
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      inputs,
      system,
      config,
      ...
    }:
    let
      inherit (lib) getExe mkDefault;
      inherit (lib.rebellion) enabled;
    in
    {
      programs.mcp = enabled;

      mcp-servers.programs = {
        # Filesystem MCP
        filesystem = enabled // {
          args = mkDefault ([ config.home.homeDirectory ] ++ cfg.filesystem.directories);
        };
        # Sequential Thinking MCP
        sequential-thinking = enabled // {
        };
      };

      mcp-servers.settings.servers = {
        # Devenv MCP (auto-detects project root from working directory)
        devenv = {
          type = "stdio";
          command = getExe pkgs.devenv;
          args = [ "mcp" ];
        };
      };
    };
}
