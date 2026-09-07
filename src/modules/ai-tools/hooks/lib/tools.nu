# Shared helpers for hook scripts. Loaded with `use lib *`; the include path is
# set by `mk-nu-script`, so this resolves both at run time and under nu-check.

export def is-macos []: nothing -> bool {
  (sys host | get name) == "Darwin"
}

export def is-linux []: nothing -> bool {
  (sys host | get name) == "Linux"
}

# The hook payload on stdin. Top-level `$in` does not compile in a script, so
# /dev/stdin is the portable way to consume it. Fails if there is none.
export def read-input []: nothing -> record {
  open --raw /dev/stdin | from json
}

# Like `read-input`, but {} when stdin is a terminal, empty, or not JSON.
export def payload []: nothing -> record {
  if (is-terminal --stdin) { return {} }
  let raw = try { open --raw /dev/stdin } catch { "" }
  if ($raw | str trim | is-empty) { {} } else { try { $raw | from json } catch { {} } }
}

# Run a command from a list (so dash-words are not parsed as flags of the
# helper) and capture everything. Stdout becomes session context for Claude in
# several hooks; command noise stays suppressed.
export def run-quiet [args: list<string>] {
  do { ^($args | first) ...($args | skip 1) } | complete
}

# `run-quiet`, re-emitting the command's stderr on our stderr so it stays out
# of stdout, which some hooks reserve for a single value.
export def try-run [args: list<string>] {
  let res = do { ^($args | first) ...($args | skip 1) } | complete
  if ($res.stderr | is-not-empty) { print -e ($res.stderr | str trim) }
  $res
}

# `try-run` that also moves stdout to stderr and exits on failure.
export def run-or-die [args: list<string>] {
  let res = try-run $args
  if ($res.stdout | is-not-empty) { print -e ($res.stdout | str trim) }
  if $res.exit_code != 0 { exit 1 }
}

# Deny a tool call: JSON decision on stdout + exit 2.
export def deny [reason: string] {
  {
    hookSpecificOutput: {
      permissionDecision: "deny"
      permissionDecisionReason: $reason
    }
  } | to json -r | print
  exit 2
}
