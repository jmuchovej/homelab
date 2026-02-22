{ lib, pkgs, ... }:
let
  statusLine = pkgs.writeShellApplication {
    name = "claude-status-line";
    runtimeInputs = with pkgs; [
      jq
      git
      coreutils
      gawk
    ];
    text = ''
      input=$(cat)

      cwd=$(echo "$input" | jq -r '.workspace.current_dir')
      model=$(echo "$input" | jq -r '.model.display_name')
      used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
      output_style=$(echo "$input" | jq -r '.output_style.name // empty')

      # Directory: last 2 path segments
      dir_display=$(echo "$cwd" | awk -F/ '{if (NF>1) print $(NF-1)"/"$NF; else print $NF}')
      printf '\033[1;36m%s\033[0m' "$dir_display"

      # Git branch with dirty indicator
      if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
        if ! git -C "$cwd" --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then
          printf ' \033[1mon\033[0m \033[33m%s*\033[0m' "$branch"
        else
          printf ' \033[1mon\033[0m \033[32m%s\033[0m' "$branch"
        fi
      fi

      # Model (strip "Claude " prefix)
      model_short=''${model#Claude }
      printf ' \033[34m[%s]\033[0m' "$model_short"

      # Context window usage (green < 50%, yellow 50-79%, red >= 80%)
      if [ -n "$used_pct" ]; then
        used_int=$(printf '%.0f' "$used_pct")
        if [ "$used_int" -ge 80 ]; then
          printf ' \033[31m%s%%\033[0m' "$used_int"
        elif [ "$used_int" -ge 50 ]; then
          printf ' \033[33m%s%%\033[0m' "$used_int"
        else
          printf ' \033[32m%s%%\033[0m' "$used_int"
        fi
      fi

      # Output style (if non-default)
      if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
        printf ' \033[35m(%s)\033[0m' "$output_style"
      fi
    '';
  };
in
{
  programs.claude-code.settings.statusLine = {
    type = "command";
    command = lib.getExe statusLine;
  };
}
