#!/usr/bin/env nu

# Compact log entry; excludes potentially large tool_output.
let input = open --raw /dev/stdin | from json
let audit_dir = $env.HOME | path join ".local/share/claude-code/audit"
mkdir $audit_dir

{
  timestamp: (date now | format date "%+")
  session: ($input.session_id? | default "unknown")
  tool: ($input.tool_name? | default "unknown")
  cwd: ($input.cwd? | default "unknown")
  success: true
} | to json -r | $"($in)\n" | save --append --raw ($audit_dir | path join "post-tool.jsonl")
