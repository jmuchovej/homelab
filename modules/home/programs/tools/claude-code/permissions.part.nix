{ cfg, ... }:
let
  # Helper to filter out specific rules
  without = rules: exclusions: builtins.filter (rule: !(builtins.elem rule exclusions)) rules;

  # Conservative operations - always allowed regardless of profile
  allow.conservative = [
    # Core Claude Code tools
    "Glob(*)"
    "Grep(*)"
    "LS(*)"
    "Read(*)"
    "Search(*)"
    "Task(*)"
    "TodoWrite(*)"

    # Safe read-only git commands
    "Bash(git status)"
    "Bash(git log:*)"
    "Bash(git diff:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(git remote:*)"

    # Safe file system operations
    "Bash(ls:*)"
    "Bash(find:*)"
    "Bash(cat:*)"
    "Bash(head:*)"
    "Bash(tail:*)"

    # Safe nix read operations
    "Bash(nix eval:*)"
    "Bash(nix flake show:*)"
    "Bash(nix flake metadata:*)"

    # MCP tools - read only
    "mcp__github__search_repositories"
    "mcp__github__get_file_contents"
    "mcp__sequential-thinking__sequentialthinking"

    # Devenv MCP
    "mcp__mcp_devenv_sh__search_options"
    "mcp__mcp_devenv_sh__search_packages"

    # Filesystem MCP - read operations
    "mcp__filesystem__read_file"
    "mcp__filesystem__read_text_file"
    "mcp__filesystem__read_media_file"
    "mcp__filesystem__read_multiple_files"
    "mcp__filesystem__list_directory"
    "mcp__filesystem__list_directory_with_sizes"
    "mcp__filesystem__directory_tree"
    "mcp__filesystem__search_files"
    "mcp__filesystem__get_file_info"
    "mcp__filesystem__list_allowed_directories"

    # Trusted web domains
    "WebFetch(domain:github.com)"
    "WebFetch(domain:raw.githubusercontent.com)"
    "WebFetch(domain:devenv.sh)"
  ];

  # Standard profile additions - balanced permissions
  allow.standard = allow.conservative ++ [
    # Git staging
    "Bash(git add:*)"

    # All nix commands
    "Bash(nix:*)"

    # Directory creation
    "Bash(mkdir:*)"
    "Bash(chmod:*)"

    # Search tools
    "Bash(rg:*)"
    "Bash(grep:*)"

    # System info
    "Bash(systemctl list-units:*)"
    "Bash(systemctl list-timers:*)"
    "Bash(systemctl status:*)"
    "Bash(journalctl:*)"
    "Bash(dmesg:*)"
    "Bash(env)"
    "Bash(claude --version)"
    "Bash(nh search:*)"

    # Debugging
    "Bash(coredumpctl list:*)"
  ];

  # Autonomous profile additions - full autonomy for trusted workflows
  allow.autonomous = allow.standard ++ [
    # Git write operations
    "Bash(git commit:*)"
    "Bash(git checkout:*)"
    "Bash(git switch:*)"
    "Bash(git stash:*)"
    "Bash(git restore:*)"
    "Bash(git reset:*)"

    # File operations
    "Bash(rm:*)"
  ];

  # Autonomous mode still requires confirmation for these
  ask.autonomous = [
    # Always confirm pushing
    "Bash(git push:*)"
    "Bash(git merge:*)"
    "Bash(git rebase:*)"

    # System operations
    "Bash(systemctl:*)"
    "Bash(nixos-rebuild:*)"
    "Bash(sudo:*)"

    # Network operations
    "Bash(curl:*)"
    "Bash(rsync:*)"
    "Bash(scp:*)"
    "Bash(ssh:*)"
    "Bash(wget:*)"

    # Process management
    "Bash(kill:*)"
    "Bash(killall:*)"
    "Bash(pkill:*)"
  ];
  # Operations requiring confirmation in non-autonomous mode
  ask.standard = (without ask.autonomous [ "Bash(systemctl:*)" ]) ++ [
    # Potentially destructive git commands
    "Bash(git checkout:*)"
    "Bash(git commit:*)"
    "Bash(git pull:*)"
    "Bash(git reset:*)"
    "Bash(git restore:*)"
    "Bash(git stash:*)"
    "Bash(git switch:*)"

    # File deletion and modification
    "Bash(cp:*)"
    "Bash(mv:*)"
    "Bash(rm:*)"

    # System control operations
    "Bash(systemctl disable:*)"
    "Bash(systemctl enable:*)"
    "Bash(systemctl mask:*)"
    "Bash(systemctl reload:*)"
    "Bash(systemctl restart:*)"
    "Bash(systemctl start:*)"
    "Bash(systemctl stop:*)"
    "Bash(systemctl unmask:*)"

    # Network operations
    "Bash(ping:*)"
  ];
  ask.conservative = ask.standard ++ allow.standard;

  # Never allowed - dangerous operations
  deny = [
    "Bash(rm -rf /*)"
    "Bash(rm -rf /)"
    "Bash(dd:*)"
    "Bash(mkfs:*)"
    "Read(./.envrc.local)"
    "Read(./secrets/**)"
  ];

  default-mode = {
    autonomous = "acceptEdits";
  };
in
{
  programs.claude-code.settings.permissions = {
    allow = allow.${cfg.code.permissions-profile};
    ask = ask.${cfg.code.permissions-profile};
    inherit deny;
    defaultMode = default-mode.${cfg.code.permissions-profile} or "default";
  };
}
