#!/usr/bin/env nu

# Stdout becomes session context for Claude; command noise stays suppressed.
use lib *

let input = tools read-input
let audit_dir = harness data-dir audit
mkdir $audit_dir

{
  timestamp: (date now | format date "%+")
  event: "session_start"
  session: ($input.session_id? | default "unknown")
  cwd: ($input.cwd? | default "unknown")
} | to json -r | $"($in)\n" | save --append --raw ($audit_dir | path join "sessions.jsonl")

# Toolchain nudge: pre-empt the PreToolUse guard so bare commands rarely get
# denied. The hook env is the session's launch env.
let cwd = $input.cwd? | default $env.PWD
let tree = toolchain detect $cwd
if ($tree.kind | is-not-empty) and (not $tree.active) {
  print "=== Toolchain ==="
  print $"This is a ($tree.kind) project \(root: ($tree.root)\) and the session was launched outside its environment."
  print $"Run every shell command wrapped: `($tree.wrap)`. Bare commands will be denied."
  print ""
}

print "=== Git Status ==="
let git_status = tools run-quiet [git status]
if $git_status.exit_code == 0 {
  print ($git_status.stdout | str trim)
} else {
  print "Not a git repository"
}

print "\n=== Recent Commits ==="
let git_log = tools run-quiet [git log --oneline -5]
if $git_log.exit_code == 0 {
  print ($git_log.stdout | str trim)
}

print "\n=== Jujutsu Status ==="
let jj_status = tools run-quiet [jj status]
if $jj_status.exit_code == 0 {
  print ($jj_status.stdout | str trim)
}

print "\n=== Current Jujutsu Change ==="
let jj_change = tools run-quiet [jj log -r @ --no-graph]
if $jj_change.exit_code == 0 {
  print ($jj_change.stdout | str trim)
} else {
  print "Not a jujutsu repository"
}
