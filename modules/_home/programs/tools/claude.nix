{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.claude";

  options =
    { lib, ... }:
    let
      inherit (lib.rebellion.options) mk mk-enable';
      inherit (lib.types) enum;
    in
    {
      desktop = mk-enable' "Claude Desktop";
      code = (mk-enable' "Claude Code") // {
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
      inherit (lib) mkIf mkMerge;
      inherit (lib.rebellion.fs) get-file import-dir;

      ai-tools = import (get-file "modules/_common/ai-tools/ai-tools.part.nix") { inherit lib pkgs; };
      inherit (ai-tools) claude-code;

      permissions = import ./claude-code/permissions.part.nix { inherit cfg; };
      status-line = import ./claude-code/status-line.part.nix { inherit lib pkgs; };

      mcp-module = config.rebellion.programs.terminal.tools.mcp;
    in
    mkMerge [
      {
        xdg.dataFile."icons/claude.ico".source = ./claude-code/assets/claude.ico;

        rebellion.homebrew.casks = mkIf (cfg.desktop.enable && pkgs.stdenv.isDarwin) [ "claude" ];

        programs.claude-code = mkIf cfg.code.enable {
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

          memory.source = get-file "modules/_common/ai-tools/BASE.md";

          # enabledPlugins = {
          #   "typescript-lsp@claude-plugins-official" = true;
          #   "rust-analyzer-lsp@claude-plugins-official" = true;
          #   "swift-lsp@claude-plugins-official" = true;
          #   "kotlin-lsp@claude-plugins-official" = true;
          #   "plugin-dev@claude-plugins-official" = true;
          #   "hookify@claude-plugins-official" = true;
          #   # "playground@claude-plugins-official" = true;
          #   # "feature-dev@claude-plugins-official" = true;
          # };
        };
      }
      # (mkIf mcp-module.enable {
      #   mcp-servers.flavors.claude-code.enable = true;
      #   mcp-servers.flavors.claude.enable = true;
      # })
      permissions
      status-line
    ];
}
