{
  __findFile,
  den,
  inputs,
  rbn-policies,
  ...
}:
{
  rbn.programs._.ai-tools._.claude = {
    includes = [
      <rbn/programs/ai-tools/claude/cli>
      (rbn-policies.when-desktop "claude" <rbn/programs/ai-tools/claude/desktop>)
    ];

    _.cli = {
      includes = [
        (den.batteries.unfree [ "claude-code" ])
        <rbn/programs/ai-tools/skills>
        <rbn/programs/ai-tools/skills/claude>
      ];

      hm-linux =
        { pkgs, ... }:
        {
          home.packages = [
            pkgs.bubblewrap
            pkgs.socat
          ];
        };

      hm =
        { lib, pkgs, ... }:
        let
          harness = {
            name = "claude-code";
            app = "Claude Code";
            icon = "claude";
            sender = "com.anthropic.claudecode";
          };
          ai-tools-lib = import ./_lib.nix {
            inherit lib pkgs harness;
            inherit (inputs) import-tree;
            hooks-dir = ./hooks;
          };
          inherit (ai-tools-lib) load-tools mk-nu-script;
          inherit (lib)
            getExe
            mapAttrs
            optionalAttrs
            ;

          vcs = [
            pkgs.jujutsu
            pkgs.git
          ];

          # One row per `hooks/<name>.nu`: what it needs on PATH (`bins`) and
          # which Claude events run it
          # (`on.<Event> = { matcher?, timeout?, condition? }`). `condition` is
          # the hook's `if` field: permission-rule syntax the harness evaluates
          # before spawning the command.
          # `status-line` is built the same way but is not a hook.
          hook-scripts = {
            # Regex-based security checks the permission lists can't express.
            pre-tool-use.on.PreToolUse = {
              matcher = "Bash|Write|Edit|MultiEdit|Read";
              timeout = 5;
            };
            pre-tool-audit.on.PreToolUse = {
              matcher = "*";
              timeout = 10;
            };
            prune-comments = {
              bins = [ pkgs.jujutsu ];
              on.PreToolUse = {
                matcher = "Bash";
                condition = "Bash(jj commit *)";
                timeout = 240;
              };
            };
            post-tool-audit.on.PostToolUse = {
              matcher = "*";
              timeout = 10;
            };
            post-tool-validate.on.PostToolUse = {
              matcher = "Write|Edit";
              timeout = 5;
            };
            pre-compact = {
              bins = [ pkgs.git ];
              on.PreCompact.matcher = "*";
            };
            session-start = {
              bins = vcs;
              on.SessionStart.matcher = "*";
            };
            session-end = {
              bins = [ pkgs.git ];
              on.SessionEnd.matcher = "*";
            };
            subagent-stop.on.SubagentStop = {
              matcher = "*";
              timeout = 10;
            };
            notify.on.Notification = { };
            worktree-rename = {
              bins = [ pkgs.jujutsu ];
              on = {
                UserPromptSubmit.timeout = 10;
                Stop.timeout = 10;
              };
            };
            worktree-create = {
              bins = vcs;
              on.WorktreeCreate.timeout = 600;
            };
            worktree-remove = {
              bins = vcs;
              on.WorktreeRemove.timeout = 120;
            };
          };

          status-line = mk-nu-script "status-line" { bins = [ pkgs.git ]; };

          mk-hook =
            name:
            {
              timeout ? null,
              condition ? null,
              bins ? [ ],
              matcher ? "",
              ...
            }:
            let
              script = mk-nu-script name { inherit bins; };
              this-hook = {
                type = "command";
                command = getExe script;
              }
              // optionalAttrs (timeout != null) { inherit timeout; }
              // optionalAttrs (condition != null) { "if" = condition; };
            in
            {
              inherit matcher;
              hooks = [ this-hook ];
            };

          # Invert the table into Claude's shape, event -> [hook]. The event
          # spec is spread into `mk-hook`'s arguments, not nested under a key.
          hooks = lib.zipAttrsWith (_: lib.concatLists) (
            lib.mapAttrsToList (
              script-name: script-row:
              mapAttrs (_: spec: [
                (mk-hook script-name ({ bins = script-row.bins or [ ]; } // spec))
              ]) script-row.on
            ) hook-scripts
          );
        in
        {
          programs.claude-code = {
            enable = true;
            enableMcpIntegration = true;

            commands = load-tools ./commands;
            agents = load-tools ./agents;

            settings = {
              inherit hooks;

              theme = "auto";
              editorMode = "vim";

              verbose = true;
              includeCoAuthoredBy = false;

              env = {
                USE_BUILTIN_RIPGREP = "0";
                NO_COLOR = "1";
              };

              statusLine = {
                type = "command";
                command = lib.getExe status-line;
              };

              sandbox = {
                enabled = false;
                credentials =
                  let
                    mk-credential = key: mode: value: {
                      "${key}" = value;
                      inherit mode;
                    };
                    mk-deny = key: value: mk-credential key "deny" value;
                    mk-mask = key: value: mk-credential key "mask" value;
                    mk-file-deny = path: mk-deny "path" path;
                    mk-env-mask = name: mk-mask "name" name;
                  in
                  {
                    files = [
                      (mk-file-deny "~/.ssh")
                    ];
                    envVars = [
                      (mk-env-mask "SOPS_AGE_KEY")
                      (mk-env-mask "GITHUB_TOKEN")
                    ];
                  };
                network = {
                  allowedDomains = [
                    "raw.githubusercontent.com"
                    "github.com"
                    "openbao.org"
                    "mynixos.com"
                    "registry.terraform.io"
                    "devenv.sh"
                    "flake.parts"
                    "docs.goauthentik.io"
                    "integrations.goauthentik.io"
                    "tailscale.com"
                    "nixos.org"
                    "noogle.dev"
                    "nix.dev"
                    "api.github.com"
                    "kdl.dev"
                    "den.denful.dev"
                    "import-tree.denful.dev"
                    "search.nixos.org"
                    "waypoints.so"
                  ];
                };
              };
            };

            context = ./_system-prompt.md;
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
