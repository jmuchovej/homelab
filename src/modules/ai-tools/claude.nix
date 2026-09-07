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
          # The identity every hook reads through `hooks/lib/harness.nu`: data
          # dir suffix, notification title and icon, macOS sender.
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
          inherit (lib) getExe;

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
            # Prune generation-scratch comments from `@` before `jj commit`
            # lands it. Runs a headless agent, hence the generous timeout; the
            # script fails open. `claude` comes from the session PATH, not
            # `bins`, so the unfree package stays out of the wrapper closure.
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
            # Both notify through `lib/notify.nu`; `mk-nu-script` puts the
            # notifier's tools on every script's PATH, so no `bins` here.
            subagent-stop.on.SubagentStop = {
              matcher = "*";
              timeout = 10;
            };
            notify.on.Notification = { };
            # Label bridge-session jj workspaces after their task; the label may
            # improve between the first prompt and the first stop (AI title).
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
            status-line.bins = [ pkgs.git ];
          };

          scripts = lib.mapAttrs (name: row: mk-nu-script name { bins = row.bins or [ ]; }) hook-scripts;

          mk-hook =
            {
              command,
              matcher ? "",
              timeout ? null,
              condition ? null,
            }:
            {
              inherit matcher;
              hooks = [
                (
                  {
                    type = "command";
                    inherit command;
                  }
                  // lib.optionalAttrs (timeout != null) { inherit timeout; }
                  // lib.optionalAttrs (condition != null) { "if" = condition; }
                )
              ];
            };

          # Invert the table into Claude's shape, event -> [hook].
          hooks = lib.zipAttrsWith (_: lib.concatLists) (
            lib.mapAttrsToList (
              name: row:
              lib.mapAttrs (_: spec: [ (mk-hook (spec // { command = getExe scripts.${name}; })) ]) (
                row.on or { }
              )
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
                # Plain output from jj, eza and friends; escape codes break
                # parsing. Applies to the session and its subprocesses.
                NO_COLOR = "1";
              };

              statusLine = {
                type = "command";
                command = lib.getExe scripts.status-line;
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
