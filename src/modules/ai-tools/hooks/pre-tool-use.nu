#!/usr/bin/env nu

# Pattern-based security validation that permissions.nix can't express
# (regex-based detection). One script for both matchers, branched on tool_name.
# `tools deny` = JSON decision on stdout + exit 2.

use lib *

let input = tools read-input

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
    tools deny "Dangerous command pattern detected"
  }

  # Enforce devenv for trees that carry one. The hook env is the session's
  # launch env, so DEVENV_ROOT reflects whether the session started inside
  # the right `devenv shell`; a worktree of a devenv tree has its own root
  # and is enforced separately. Warm invocations cost ~0.3s (eval cache);
  # the first one in a fresh tree pays a one-time eval.
  let cwd = $input.cwd? | default $env.PWD
  let devenv_root = devenv find-root $cwd
  if ($devenv_root | is-not-empty) {
    let in_shell = ($env.DEVENV_ROOT? | default "") == $devenv_root
    let wrapped = $cmd =~ '(^|\s)devenv(\s|$)' or $cmd =~ '(^|\s)nix develop(\s|$)'
    if (not $in_shell) and (not $wrapped) {
      tools deny ($"This tree uses devenv \(($devenv_root)\) and the session was not "
        + "launched inside its shell. Re-run the command as: devenv shell -q -- <cmd>")
    }
  }
} else {
  # Path traversal in path-bearing fields ONLY. Scanning every value also
  # searched file CONTENT, so an edit was denied whenever the text it touched
  # happened to contain a relative parent reference — kustomize overlays,
  # relative imports in JS/Python, even prose.
  let ti = $input.tool_input? | default {}
  let paths = [
    ($ti.file_path? | default "")
    ($ti.path? | default "")
    ($ti.notebook_path? | default "")
  ]
  if ($paths | any { |p| $p =~ '\.\./' }) {
    tools deny "Path traversal attempt detected"
  }
}

exit 0
