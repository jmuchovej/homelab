#!/usr/bin/env nu

use lib *

let input = tools read-input
let cwd = $input.workspace?.current_dir? | default ""
let model = $input.model?.display_name? | default ""
let used_pct = $input.context_window?.used_percentage? | default null
let output_style = $input.output_style?.name? | default ""

# Directory: last 2 path segments
let dir_display = $cwd | path split | where { |p| $p != "/" } | last 2 | str join "/"
print -n $"(ansi cyan_bold)($dir_display)(ansi reset)"

# Git branch with dirty indicator
let git_dir = tools run-quiet [git -C $cwd rev-parse --git-dir]
if $git_dir.exit_code == 0 {
  let branch_res = tools run-quiet [git -C $cwd --no-optional-locks branch --show-current]
  let branch = if $branch_res.exit_code == 0 and ($branch_res.stdout | str trim | is-not-empty) {
    $branch_res.stdout | str trim
  } else {
    "detached"
  }
  let clean = (tools run-quiet [git -C $cwd --no-optional-locks diff-index --quiet HEAD --]).exit_code == 0
  if $clean {
    print -n $" (ansi attr_bold)on(ansi reset) (ansi green)($branch)(ansi reset)"
  } else {
    print -n $" (ansi attr_bold)on(ansi reset) (ansi yellow)($branch)*(ansi reset)"
  }
}

# Model (strip "Claude " prefix)
let model_short = $model | str replace -r '^Claude ' ''
print -n $" (ansi blue)[($model_short)](ansi reset)"

# Context window usage (green < 50%, yellow 50-79%, red >= 80%)
if $used_pct != null {
  let used_int = $used_pct | math round
  let color = if $used_int >= 80 {
    ansi red
  } else if $used_int >= 50 {
    ansi yellow
  } else {
    ansi green
  }
  print -n $" ($color)($used_int)%(ansi reset)"
}

# Output style (if non-default)
if ($output_style | is-not-empty) and $output_style != "default" {
  print -n $" (ansi purple)\(($output_style)\)(ansi reset)"
}
