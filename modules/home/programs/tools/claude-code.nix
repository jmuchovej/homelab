{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.claude-code";

  options =
    { lib, ... }:
    let
      inherit (lib.rebellion.options) mk;
      inherit (lib.types) enum listOf str;
    in
    {
      permissions-profile =
        mk
          (enum [
            "conservative"
            "standard"
            "autonomous"
          ])
          "standard"
          ''
            Permission profile for Claude Code:
            - `conservative`: Minimal permissions, most operations require confirmation
            - `standard`: Balanced permissions for normal development workflows
            - `autonomous`: Maximum autonomy for trusted environments
          '';
      mcp-servers = {
        fs = {
          directories = mk (listOf str) [ ] "Directories that MCP servers can access.";
        };
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rebellion.fs) get-file import-dir;

      ai-tools = import (get-file "modules/common/ai-tools/ai-tools.nix") { inherit lib pkgs; };
      inherit (ai-tools) claude-code;

      permissions = import ./claude-code/permissions.part.nix { inherit cfg; };
      mcp-servers = import ./claude-code/mcp-servers.part.nix {
        inherit
          cfg
          lib
          pkgs
          config
          ;
      };

      statusLine = import ./claude-code/status-line.part.nix { inherit lib pkgs; };
    in
    mkMerge [
      {
        xdg.dataFile."icons/claude.ico".source = ./claude-code/assets/claude.ico;

        programs.claude-code = {
          enable = true;

          inherit (claude-code) agents commands;

          settings = {
            theme = "dark";

            hooks = import-dir ./claude-code/hooks { inherit pkgs; };

            verbose = true;
            includeCoAuthoredBy = false;
          };

          skillsDir = ai-tools.skills;

          memory.source = get-file "modules/common/ai-tools/BASE.md";
        };
      }
      permissions
      mcp-servers
      statusLine
    ];
}
