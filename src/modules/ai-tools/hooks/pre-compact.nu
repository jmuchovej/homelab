#!/usr/bin/env nu

def run-quiet [args: list<string>] {
  do { ^($args | first) ...($args | skip 1) } | complete
}

let input = open --raw /dev/stdin | from json
let session_id = $input.session_id? | default "unknown"
let backups = $env.HOME | path join ".local/share/claude-code/context-backups"
mkdir $backups
let backup_file = $backups | path join $"compact-(date now | format date '%Y%m%d-%H%M%S').log"

# Recent tool activity for this session, as "count tool" lines
let pre_tool = $env.HOME | path join ".local/share/claude-code/audit/pre-tool.jsonl"
let activity = if ($pre_tool | path exists) {
  open --raw $pre_tool
  | lines
  | each { |l| try { $l | from json } catch { null } }
  | where { |r| ($r | describe) =~ '^record' }
  | where { |r| ($r.session? | default "") == $session_id }
  | last 20
  | each { |r| $r.tool? | default "unknown" }
  | uniq --count
  | sort-by -r count
  | each { |r| $"  ($r.count) ($r.value)" }
} else {
  []
}

let git_status = run-quiet [git status --short]
let git_diff = run-quiet [git diff --name-only HEAD]

[
  $"=== Context Compaction at (date now) ==="
  $"Session ID: ($session_id)"
  $"Working Directory: ($env.PWD)"
  ""
  "Recent Tool Activity:"
  (if ($activity | is-empty) { "No tool activity recorded" } else { $activity | str join "\n" })
  ""
  "Git Status:"
  (if $git_status.exit_code == 0 { $git_status.stdout | str trim } else { "Not a git repository" })
  ""
  "Recently Modified Files:"
  (if $git_diff.exit_code == 0 { $git_diff.stdout | str trim } else { "N/A" })
  ""
] | str join "\n" | save --append --raw $backup_file
