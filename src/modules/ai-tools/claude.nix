{ den, inputs, ... }:
{
  flake-file.inputs.anthropic-skills = {
    flake = false;
    url = "github:anthropics/skills/1ed29a03dc852d30fa6ef2ca53a67dc2c2c2c563";
  };

  rbn.programs._.ai-tools._.claude = {
    provides.code =
      let
        permission-profiles = import ./_claude/permissions.nix;
      in
      {
        includes = [ (den.batteries.unfree [ "claude-code" ]) ];

        homeManager =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            inherit (lib) mkOption;
            inherit (lib.rbn) import-dir;

            ai-tools = import ./_ai-tools {
              inherit lib;
              anthropic-skills-src = inputs.anthropic-skills;
            };
            inherit (ai-tools) claude-code;

            hooks-dir = ./_claude/hooks;
            status-line = import ./_claude/status-line.nix {
              inherit lib pkgs;
            };
          in
          {
            # Define options (replaces old mk-module option definitions)
            options.rebellion.programs.ai-tools.claude = {
              code = {
                enable = mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable Claude Code";
                };
                permissions-profile = mkOption {
                  type = lib.types.enum [
                    "conservative"
                    "standard"
                    "autonomous"
                  ];
                  default = "standard";
                  description = "Permission profile for Claude Code.";
                };
              };
            };

            config = lib.mkMerge [
              {
                xdg.dataFile."icons/claude.ico".source = ./_claude/assets/claude.ico;

                programs.claude-code = {
                  enable = true;

                  enableMcpIntegration = config.programs.mcp.enable;

                  inherit (claude-code) agents commands;

                  settings = {
                    theme = "dark";

                    hooks = import-dir hooks-dir { inherit pkgs; };

                    verbose = true;
                    includeCoAuthoredBy = false;

                    env = {
                      USE_BUILTIN_RIPGREP = "0";
                    };
                  };

                  inherit (ai-tools) skills;

                  context = ./_ai-tools/BASE.md;
                };
              }
              status-line
            ];
          };
        provides.conservative.homeManager = {
          programs.claude-code.settings.permissions = {
            allow = permission-profiles.allow.conservative;
            ask = permission-profiles.ask.conservative;
            deny = permission-profiles.deny.conservative;
            defaultMode = "conservative";
          };
        };
        provides.standard.homeManager = {
          programs.claude-code.settings.permissions = {
            allow = permission-profiles.allow.standard;
            ask = permission-profiles.ask.standard;
            deny = permission-profiles.deny.standard;
            defaultMode = "standard";
          };
        };
        provides.autonomous.homeManager = {
          programs.claude-code.settings.permissions = {
            allow = permission-profiles.allow.autonomous;
            ask = permission-profiles.ask.autonomous;
            deny = permission-profiles.deny.autonomous;
            defaultMode = "autonomous";
          };
        };
      };

    provides.desktop.dock.app = "Claude.app";
    provides.desktop.darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "claude" ];
      };
  };
}
