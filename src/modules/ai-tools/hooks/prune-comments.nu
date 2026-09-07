#!/usr/bin/env nu

# PreToolUse hook gated on `jj commit` (the row's `condition` in claude.nix):
# prune generation-scratch comments from the working-copy change before it
# lands.
#
# A fresh-context agent sees only the `@` diff and may delete comments that
# appear on ADDED lines. Lacking the authoring session's context is the point:
# a comment that only makes sense with that context is exactly what should go.
#
# Everything fails open. A skipped prune is cheap; a stalled pipeline is not.

const comment_line = '^\+\s*(#|//|/\*|\*\s|--|;|<!--)'

def added-comment-count [diff: string] {
  $diff | lines | where { |l| $l =~ $comment_line } | length
}

def working-copy-diff [] {
  jj diff -r @ --git | complete
}

# One runner per harness. Each turns the diff into edits on disk and returns
# a `complete` record; the caller only looks at exit_code and stderr.
def run-claude [diff: string] {
  let prompt = [
    "Prune superfluous comments from the working-copy change."
    "The unified diff of that change follows. Only comments on added (+) lines are in scope."
    "Use Edit to remove them in place. Do not touch anything else."
    ""
    $diff
  ] | str join "\n"

  # Prompt goes over stdin: `--tools`/`--allowedTools` are variadic and would
  # swallow a positional prompt. Tool restrictions and model come from the
  # agent's frontmatter.
  $prompt
  | claude -p --agent commit-cleaner --effort low --permission-mode acceptEdits --output-format text
  | complete
}

def main [--runtime: string = "claude"] {
  # The headless run inherits the session env, and its own tool calls pass
  # through this same hook.
  if ($env.PRUNE_COMMENTS_ACTIVE? | default "") == "1" { exit 0 }

  let input = open --raw /dev/stdin | from json
  cd ($input.cwd? | default $env.PWD)

  # Snapshot first so the agent's edits and the pruner's edits land in
  # separate operations: `jj op diff` then shows exactly what was pruned and
  # `jj op restore` undoes only the prune.
  jj status o+e>| ignore

  let diff = working-copy-diff
  if $diff.exit_code != 0 { exit 0 }
  let before = added-comment-count $diff.stdout
  if $before == 0 { exit 0 }

  let result = with-env { PRUNE_COMMENTS_ACTIVE: "1" } {
    match $runtime {
      "claude" => (run-claude $diff.stdout)
      _ => {
        print -e $"prune-comments: no runner for runtime '($runtime)'"
        exit 0
      }
    }
  }
  if $result.exit_code != 0 {
    print -e $"prune-comments: runner failed \(exit ($result.exit_code)\); committing unpruned"
    print -e $result.stderr
    exit 0
  }

  let after = added-comment-count (working-copy-diff | get stdout)
  {
    systemMessage: $"prune-comments: added comment lines in @ went from ($before) to ($after)"
  } | to json -r | print
  exit 0
}
