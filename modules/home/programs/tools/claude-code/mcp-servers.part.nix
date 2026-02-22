{
  cfg,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkMerge getExe;
in
{
  programs.claude-code.mcpServers = mkMerge [
    # Filesystem MCP
    {
      filesystem = {
        type = "stdio";
        command = getExe pkgs.mcp-server-filesystem;
        args = [ config.home.homeDirectory ] ++ cfg.mcp-servers.fs.directories;
      };
    }
    # GitHub MCP: allow read-only for safety
    {
      github = {
        type = "stdio";
        command = getExe pkgs.github-mcp-server;
        args = [
          "--read-only"
          "stdio"
        ];
      };
    }
    # Sequential Thinking MCP
    {
      sequential-thinking = {
        type = "stdio";
        command = getExe pkgs.mcp-server-sequential-thinking;
      };
    }
    # Devenv MCP (auto-detects project root from working directory)
    {
      devenv = {
        type = "stdio";
        command = "devenv";
        args = [ "mcp" ];
      };
    }
  ];
}
