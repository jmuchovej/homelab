# Desktop notifier shared by the Notification hook (inline invocation) and
# subagent-stop.nu (on its wrapped PATH). Stays nix-side because the platform
# conditional belongs at build time, not in a script.
{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "claude-notify";
  text = ''
    title=''${1:-"Claude Code"}
    message=''${2:-""}

    ${
      if pkgs.stdenv.hostPlatform.isDarwin then
        ''
          # terminal-notifier (Homebrew) has better icon support; osascript is the fallback
          if command -v terminal-notifier &>/dev/null; then
            terminal-notifier -title "$title" -message "$message" \
              -sender "com.anthropic.claudecode" -sound default
          else
            osascript -e "display notification \"$message\" with title \"$title\""
          fi
        ''
      else
        ''notify-send -a "$title" -i "$HOME/.local/share/icons/claude.ico" "$title" "$message"''
    }
  '';
}
