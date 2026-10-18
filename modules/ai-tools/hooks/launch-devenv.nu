#!/usr/bin/env nu

# Keep Bash commands inside the project's own toolchain. Which toolchain a
# tree uses — and whether this session is already inside it — is decided by
# `toolchain detect`; this hook only denies and explains.

use lib *

let input = tools read-input
let cmd = $input.tool_input?.command? | default "" | str trim
let cwd = $input.cwd? | default $env.PWD

let tree = toolchain detect $cwd
if ($tree.kind | is-empty) or $tree.active { exit 0 }

# Leading `VAR=value` assignments are stripped first, as the harness does for
# `if` matching, so `SECRETSPEC_REASON="…" devenv shell -- …` counts. A value
# with an escaped quote is not parsed and falls through to a deny.
let assignments = r#'^(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|\S*)\s+)+'#
let head = $cmd | str replace --regex $assignments ''

# Already wrapped. A prefix test, not a substring one: `rg devenv` names an
# activator without being an activation.
let activators = ["devenv" "direnv" "nix develop" "nix-shell"]
if ($activators | any { |a| $head | str starts-with $a }) { exit 0 }

tools deny ($"This is a ($tree.kind) project \(($tree.root)\) and the session is not inside its"
  + " environment, so the command would run against the host toolchain rather than the"
  + $" project's pinned one. Re-run as: ($tree.wrap)")
