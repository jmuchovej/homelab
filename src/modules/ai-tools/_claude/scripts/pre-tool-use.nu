#!/usr/bin/env nu

# Pattern-based security validation that permissions.nix can't express
# (regex-based detection). One script for both matchers, branched on tool_name.
# Deny = JSON decision on stdout + exit 2.

def deny [reason: string] {
  {
    hookSpecificOutput: {
      permissionDecision: "deny"
      permissionDecisionReason: $reason
    }
  } | to json -r | print
  exit 2
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

if ($input.tool_name? | default "") == "Bash" {
  let cmd = $input.tool_input?.command? | default ""
  let dangerous = [
    # Arbitrary code execution from network (pipe to shell)
    'curl.*\|.*sh'
    'curl.*\|.*bash'
    'wget.*\|.*sh'
    'wget.*\|.*bash'
    'eval.*\$\(curl'
    'eval.*\$\(wget'
    # Fork bomb
    ':\(\)\{.*:\|:.*\};:'
  ]
  if ($dangerous | any { |pat| $cmd =~ $pat }) {
    deny "Dangerous command pattern detected"
  }

  # Enforce devenv for trees that carry one. The hook env is the session's
  # launch env, so DEVENV_ROOT reflects whether the session started inside
  # the right `devenv shell`; a worktree of a devenv tree has its own root
  # and is enforced separately. Warm invocations cost ~0.3s (eval cache);
  # the first one in a fresh tree pays a one-time eval.
  let cwd = $input.cwd? | default $env.PWD
  let devenv_root = find-devenv-root $cwd
  if ($devenv_root | is-not-empty) {
    let in_shell = ($env.DEVENV_ROOT? | default "") == $devenv_root
    let wrapped = $cmd =~ '(^|\s)devenv(\s|$)' or $cmd =~ '(^|\s)nix develop(\s|$)'
    if (not $in_shell) and (not $wrapped) {
      deny ($"This tree uses devenv \(($devenv_root)\) and the session was not "
        + "launched inside its shell. Re-run the command as: devenv shell -q -- <cmd>")
    }
  }
} else {
  # Path traversal in any tool_input value
  let vals = $input.tool_input? | default {} | values | to json -r
  if $vals =~ '\.\./' {
    deny "Path traversal attempt detected"
  }
}

exit 0
