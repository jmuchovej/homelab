{
  __findFile,
  den,
  inputs,
  rbn-policies,
  ...
}:
{
  flake-file.inputs.anthropic-skills = {
    flake = false;
    url = "github:anthropics/skills/1ed29a03dc852d30fa6ef2ca53a67dc2c2c2c563";
  };

  rbn.programs._.ai-tools._.claude = {
    includes = [
      <rbn/programs/ai-tools/claude/code>
      (rbn-policies.when-desktop "claude" <rbn/programs/ai-tools/claude/desktop>)
    ];

    _.code = {
      includes = [ (den.batteries.unfree [ "claude-code" ]) ];

      hm =
        { lib, pkgs, ... }:
        let
          inherit (inputs) import-tree;

          ai-tools = import ./_ai-tools {
            inherit lib import-tree;
            anthropic-skills-src = inputs.anthropic-skills;
          };
          inherit (ai-tools) claude-code;

          # Each hook file returns `{ <Event> = [ … ]; }`. Several files target the
          # same event — `post-tool-{audit,validate}` both define `PostToolUse`,
          # `pre-tool-{audit,use}` both define `PreToolUse` — so the lists have to
          # be concatenated per event. The previous `import-dir` shallow-merged
          # with `//` and silently kept only the last file of each pair.
          hooks = lib.zipAttrsWith (_: lib.concatLists) (
            lib.pipe import-tree [
              (i: i.initFilter (p: lib.hasSuffix ".nix" (toString p)))
              (i: i.map (p: import p { inherit pkgs; }))
              (i: i.leafs ./_claude/hooks)
            ]
          );

          status-line = import ./_claude/status-line.nix {
            inherit pkgs;
          };
        in
        {
          xdg.dataFile."icons/claude.ico".source = ./_claude/assets/claude.ico;

          programs.claude-code = {
            enable = true;
            enableMcpIntegration = true;

            inherit (claude-code) agents commands;

            settings = {
              theme = "dark";

              inherit hooks;

              verbose = true;
              includeCoAuthoredBy = false;

              env = {
                USE_BUILTIN_RIPGREP = "0";
              };

              statusLine = {
                type = "command";
                command = lib.getExe status-line;
              };
            };

            inherit (ai-tools) skills;

            context = ./_ai-tools/BASE.md;

          };
        };

      conservative.hm = _: {
        programs.claude-code.settings.permissions = {
          inherit ((import ./_claude/permissions.nix).conservative) allow ask deny;
          defaultMode = "conservative";
        };
      };

      standard.hm = _: {
        programs.claude-code.settings.permissions = {
          inherit ((import ./_claude/permissions.nix).standard) allow ask deny;
          defaultMode = "standard";
        };
      };

      autonomous.hm = _: {
        programs.claude-code.settings.permissions = {
          inherit ((import ./_claude/permissions.nix).autanomous) allow ask deny;
          defaultMode = "autonomous";
        };
      };
    };

    _.desktop = {
      dock.app = "Claude.app";
      macos.homebrew.casks = [ "claude" ];
    };
  };
}
