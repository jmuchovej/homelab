#!/usr/bin/env nu

# PreToolUse hook gated on the description-writing `jj` subcommands (the
# row's `condition` list in claude.nix): inject `--config
# rbn.assisted-by.tool=… --config rbn.assisted-by.model=…` so the jujutsu
# `templates.commit_trailers` renders `Assisted-by: <tool> (<model>)`.
#
# The template is all-or-nothing, so a command that cannot be given a model is
# denied rather than committed without the trailer. A command that already
# carries the model key is left untouched.

use lib *

# `jj` where a shell command starts: line start, after a separator, or after a
# `--` (the devenv wrapper). Deliberately NOT a bare `\bjj\b`, which would
# also rewrite a `jj` inside a quoted commit message.
const jj_at_start = '(^|[;&|(]\s*|--\s+)jj(\s)'

# `claude-fable-5-1` -> `Claude Fable 5.1`; `claude-haiku-4-5-20251001` -> `Claude Haiku 4.5`.
def display-name [id: string]: nothing -> string {
  $id
  | str replace --regex '\[.*\]$' ''
  | split row '-'
  | where { |t| $t !~ '^\d{8}$' }
  | reduce --fold '' { |t, acc|
      if ($acc | is-empty) {
        $t | str capitalize
      } else if ($t =~ '^\d+$') and ($acc =~ '\d$') {
        $'($acc).($t)'
      } else {
        $'($acc) ($t | str capitalize)'
      }
    }
}

let input = tools read-input
let cmd = $input.tool_input?.command? | default ''

if $cmd =~ 'rbn\.assisted-by\.model=' { exit 0 }

let tool = (harness).app
let model = notify model-of $input | display-name $in

if ($model | is-empty) {
  tools deny ('Could not determine the model for the Assisted-by trailer. Re-run with '
    + '--config rbn.assisted-by.tool="' + $tool + '" --config rbn.assisted-by.model="<your model>"')
}

let flags = $"jj --config 'rbn.assisted-by.tool=($tool)' --config 'rbn.assisted-by.model=($model)'"
let updated = $cmd | str replace --all --regex $jj_at_start $'${1}($flags)${2}'

{
  hookSpecificOutput: {
    hookEventName: 'PreToolUse'
    updatedInput: ($input.tool_input | update command $updated)
  }
} | to json -r | print

exit 0
