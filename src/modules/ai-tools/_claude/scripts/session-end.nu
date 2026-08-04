#!/usr/bin/env nu

def run-quiet [args: list<string>] {
  do { ^($args | first) ...($args | skip 1) } | complete
}

let input = open --raw /dev/stdin | from json
let session_id = $input.session_id? | default "unknown"
let share = $env.HOME | path join ".local/share/claude-code"
mkdir ($share | path join "sessions") ($share | path join "audit")

{
  timestamp: (date now | format date "%+")
  event: "session_end"
  session: $session_id
  cwd: ($input.cwd? | default "unknown")
} | to json -r | $"($in)\n" | save --append --raw ($share | path join "audit/sessions.jsonl")

# Count this session's tool calls from the audit trail
let pre_tool = $share | path join "audit/pre-tool.jsonl"
let tool_count = if ($pre_tool | path exists) {
  open --raw $pre_tool | lines | where { |l| $l | str contains $'"session":"($session_id)"' } | length
} else {
  0
}

let git_status = run-quiet [git status --short]
let git_lines = if $git_status.exit_code == 0 {
  $git_status.stdout | str trim
} else {
  "Not a git repository"
}

let session_log = $share | path join $"sessions/(date now | format date '%Y-%m').log"
[
  $"=== Session End: (date now) ==="
  $"Session ID: ($session_id)"
  $"Directory: ($env.PWD)"
  $"Tool calls: ($tool_count)"
  "Git Status:"
  $git_lines
  ""
  ""
] | str join "\n" | save --append --raw $session_log
