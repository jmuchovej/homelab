#!/usr/bin/env nu

# Replaces Claude Code's built-in `git worktree` creation for every worktree
# (`--worktree`, `isolation: worktree` subagents, background sessions).
# `.worktreeinclude` is not processed for hook-created worktrees — copy any
# gitignored files here if that is wanted.
#
# Two doc pages disagree about the create-hook contract:
#   - docs/en/worktrees  reads `.name` from stdin and treats stdout as the
#     path Claude Code should cd into.
#   - docs/en/hooks      documents `.worktree_path` on stdin and says stdout
#     only reaches the debug log.
# This script satisfies both: it prefers `.worktree_path`, falls back to
# `.name`, builds at the path Claude Code picked, and echoes that path as its
# only stdout. Everything else is stderr, which is what surfaces on failure.

# Args go as a list so dash-words like --ignore-working-copy aren't parsed as
# flags of the helper itself; all command output is re-emitted on stderr so
# stdout stays reserved for the worktree path.
def try-run [args: list<string>] {
  let res = do { ^($args | first) ...($args | skip 1) } | complete
  if ($res.stderr | is-not-empty) { print -e ($res.stderr | str trim) }
  $res
}

def run-or-die [args: list<string>] {
  let res = try-run $args
  if ($res.stdout | is-not-empty) { print -e ($res.stdout | str trim) }
  if $res.exit_code != 0 { exit 1 }
}

# Top-level `$in` fails to compile in current nu; /dev/stdin is the
# portable way for a script to consume the hook's JSON.
let input = open --raw /dev/stdin | from json
let cwd = if ($input.cwd? | is-empty) { $env.PWD } else { $input.cwd }
let base_commit = $input.base_commit? | default ""
let name_field = $input.name? | default ""

let worktree_path = if ($input.worktree_path? | is-empty) {
  if ($name_field | is-empty) {
    print -e "WorktreeCreate: input carried neither worktree_path nor name"
    exit 1
  }
  $"($cwd)/.claude/worktrees/($name_field)"
} else {
  $input.worktree_path
}
let name = if ($name_field | is-empty) { $worktree_path | path basename } else { $name_field }

# Reusing a name reopens the existing worktree; nothing to create.
if (($"($worktree_path)/.jj" | path exists) or ($"($worktree_path)/.git" | path exists)) {
  print $worktree_path
  exit 0
}

cd $cwd

let jj_probe = try-run [jj --ignore-working-copy root]
if $jj_probe.exit_code == 0 and ($jj_probe.stdout | str trim | is-not-empty) {
  let root = $jj_probe.stdout | str trim

  # jj resolves a git commit id as a revset in a git-backed repo, but the
  # commit is only visible once imported, so fall back to the default
  # (branch from the current workspace's parents) when it is not.
  mut revision = []
  if ($base_commit | is-not-empty) {
    let probe = do {
      ^jj -R $root --ignore-working-copy log --no-graph --limit 1 -r $base_commit -T commit_id
    } | complete
    if $probe.exit_code == 0 {
      $revision = ["-r", $base_commit]
    } else {
      print -e $"WorktreeCreate: ($base_commit) unknown to jj; branching from @-"
    }
  }

  # `jj workspace add` does not create parent directories, and it must be
  # able to update the working copy — no --ignore-working-copy here.
  mkdir $worktree_path
  run-or-die ([jj -R $root workspace add --name $name] ++ $revision ++ [$worktree_path])
} else {
  let git_probe = try-run [git rev-parse --show-toplevel]
  if $git_probe.exit_code != 0 or ($git_probe.stdout | str trim | is-empty) {
    print -e $"WorktreeCreate: ($cwd) is neither a jj nor a git repository"
    exit 1
  }
  let root = $git_probe.stdout | str trim
  let branch = $"worktree-($name)"

  mkdir ($worktree_path | path dirname)
  let res = do { ^git -C $root show-ref --verify --quiet $"refs/heads/($branch)" } | complete
  if $res.exit_code == 0 {
    run-or-die [git -C $root worktree add $worktree_path $branch]
  } else {
    let base = if ($base_commit | is-empty) { "HEAD" } else { $base_commit }
    run-or-die [git -C $root worktree add -b $branch $worktree_path $base]
  }
}

# Devenv provisioning: local overrides are gitignored, so a fresh checkout
# lacks them; copy from the main tree. The devenv eval cache is per-tree, so
# the worktree's first wrapped command pays a one-time eval.
if ($cwd | path join "devenv.nix" | path exists) {
  for f in ["devenv.local.nix"] {
    let src = $cwd | path join $f
    if ($src | path exists) { cp $src ($worktree_path | path join $f) }
  }
}

print $worktree_path
