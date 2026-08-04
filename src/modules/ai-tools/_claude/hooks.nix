{ pkgs, ... }:
let
  inherit (pkgs) lib;
  scripts = import ./scripts.nix { inherit pkgs; };
  notify = import ./notify.nix { inherit pkgs; };

  mk-hook =
    {
      command,
      matcher ? "",
      timeout ? null,
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
        )
      ];
    };

  exe = lib.getExe;
in
{
  Notification = [
    (mk-hook { command = "${exe notify} 'Claude Code' 'Awaiting your input'"; })
  ];

  PreToolUse = [
    # Regex-based security checks permissions.nix can't express
    (mk-hook {
      matcher = "Bash|Write|Edit|MultiEdit|Read";
      command = exe scripts.pre-tool-use;
      timeout = 5;
    })
    (mk-hook {
      matcher = "*";
      command = exe scripts.pre-tool-audit;
      timeout = 10;
    })
  ];

  PostToolUse = [
    (mk-hook {
      matcher = "*";
      command = exe scripts.post-tool-audit;
      timeout = 10;
    })
    (mk-hook {
      matcher = "Write|Edit";
      command = exe scripts.post-tool-validate;
      timeout = 5;
    })
  ];

  PreCompact = [
    (mk-hook {
      matcher = "*";
      command = exe scripts.pre-compact;
    })
  ];

  SessionStart = [
    (mk-hook {
      matcher = "*";
      command = exe scripts.session-start;
    })
  ];

  SessionEnd = [
    (mk-hook {
      matcher = "*";
      command = exe scripts.session-end;
    })
  ];

  SubagentStop = [
    (mk-hook {
      matcher = "*";
      command = exe scripts.subagent-stop;
      timeout = 10;
    })
  ];

  WorktreeCreate = [
    (mk-hook {
      command = exe scripts.worktree-create;
      timeout = 120;
    })
  ];

  WorktreeRemove = [
    (mk-hook {
      command = exe scripts.worktree-remove;
      timeout = 120;
    })
  ];
}
