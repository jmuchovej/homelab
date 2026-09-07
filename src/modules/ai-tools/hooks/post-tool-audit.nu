#!/usr/bin/env nu

# Compact log entry; excludes potentially large tool_output.
use lib *

let input = tools read-input
let audit_dir = harness data-dir audit
mkdir $audit_dir

{
  timestamp: (date now | format date "%+")
  session: ($input.session_id? | default "unknown")
  tool: ($input.tool_name? | default "unknown")
  cwd: ($input.cwd? | default "unknown")
  success: true
} | to json -r | $"($in)\n" | save --append --raw ($audit_dir | path join "post-tool.jsonl")
