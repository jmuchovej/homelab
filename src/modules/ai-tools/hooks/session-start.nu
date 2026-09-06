#!/usr/bin/env nu

# Stdout becomes session context for Claude; command noise stays suppressed.
def run-quiet [args: list<string>] {
  do { ^($args | first) ...($args | skip 1) } | complete
}

def find-devenv-root [start: string] {
  mut dir = $start
  loop {
    if ($dir | path join "devenv.nix" | path exists) { return $dir }
    let parent = $dir | path dirname
    if $parent == $dir { return "" }
    $dir = $parent
  }
}

let input = open --raw /dev/stdin | from json
let audit_dir = $env.HOME | path join ".local/share/claude-code/audit"
mkdir $audit_dir

{
  timestamp: (date now | format date "%+")
  event: "session_start"
  session: ($input.session_id? | default "unknown")
  cwd: ($input.cwd? | default "unknown")
} | to json -r | $"($in)\n" | save --append --raw ($audit_dir | path join "sessions.jsonl")

# Devenv nudge: pre-empt the PreToolUse guard so bare commands rarely get
# denied. The hook env is the session's launch env.
let cwd = $input.cwd? | default $env.PWD
let devenv_root = find-devenv-root $cwd
if ($devenv_root | is-not-empty) and ($env.DEVENV_ROOT? | default "") != $devenv_root {
  print "=== Toolchain ==="
  print $"This tree uses devenv \(root: ($devenv_root)\) but the session was launched outside its shell."
  print "Run every shell command wrapped: `devenv shell -q -- <cmd>`. Bare commands will be denied."
  print "The first wrapped command in a fresh tree pays a one-time eval; later ones are fast."
  print ""
}

print "=== Git Status ==="
let git_status = run-quiet [git status]
if $git_status.exit_code == 0 {
  print ($git_status.stdout | str trim)
} else {
  print "Not a git repository"
}

print "\n=== Recent Commits ==="
let git_log = run-quiet [git log --oneline -5]
if $git_log.exit_code == 0 {
  print ($git_log.stdout | str trim)
}

print "\n=== Jujutsu Status ==="
let jj_status = run-quiet [jj status]
if $jj_status.exit_code == 0 {
  print ($jj_status.stdout | str trim)
}

print "\n=== Current Jujutsu Change ==="
let jj_change = run-quiet [jj log -r @ --no-graph]
if $jj_change.exit_code == 0 {
  print ($jj_change.stdout | str trim)
} else {
  print "Not a jujutsu repository"
}
