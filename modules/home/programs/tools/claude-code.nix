{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.claude-code";

  options =
    { lib, ... }:
    let
      inherit (lib.rebellion.options) mk;
      inherit (lib.types) enum;
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
      inherit (lib.rebellion.fs) get-file get-module import-dir;

      ai-tools = import (get-module "common" "ai-tools/ai-tools") { inherit lib pkgs; };
      inherit (ai-tools) claude-code;

      permissions = import ./claude-code/permissions.part.nix { inherit cfg; };
      status-line = import ./claude-code/status-line.part.nix { inherit lib pkgs; };

      mcp-module = config.rebellion.programs.terminal.tools.mcp;
    in
    mkMerge [
      {
        xdg.dataFile."icons/claude.ico".source = ./claude-code/assets/claude.ico;

        programs.claude-code = {
          enable = true;

          enableMcpIntegration = mcp-module.enable;

          inherit (claude-code) agents commands;

          settings = {
            theme = "dark";

            hooks = import-dir ./claude-code/hooks { inherit pkgs; };

            verbose = true;
            includeCoAuthoredBy = false;

            env = {
              USE_BUILTIN_RIPGREP = "0";
            };
          };

          skillsDir = ai-tools.skills;

          memory.source = get-file "modules/common/ai-tools/BASE.md";
        };
      }
      permissions
      status-line
    ];
}
