#!/usr/bin/env nu

# Replaces Claude Code's built-in `git worktree` creation for every worktree
# (`--worktree`, `isolation: worktree` subagents, background sessions).
# `.worktreeinclude` is not processed for hook-created worktrees — copy any
# gitignored files here if that is wanted.
#
# Stdout is the path Claude Code adopts as the session's worktree. It is never
# the in-repo `worktree_path` Claude proposed: every worktree lives under
# `harness worktrees-dir` as `<repo>--<name>` (why: ai-tools/AGENTS.md).

# `tools try-run` / `tools run-or-die` re-emit all command output on stderr so stdout
# stays reserved for the worktree path.
use lib *

# Reusing a name reopens the existing worktree; nothing to create.
def reuse [dir: string] {
  if (($"($dir)/.jj" | path exists) or ($"($dir)/.git" | path exists)) {
    print $dir
    exit 0
  }
}

let input = tools read-input
let cwd = if ($input.cwd? | is-empty) { $env.PWD } else { $input.cwd }
let base_commit = $input.base_commit? | default ""
let name = if ($input.name? | is-empty) {
  if ($input.worktree_path? | is-empty) {
    print -e "WorktreeCreate: input carried neither name nor worktree_path"
    exit 1
  }
  $input.worktree_path | path basename
} else {
  $input.name
}

cd $cwd

let jj_probe = tools try-run [jj --ignore-working-copy root]
let is_jj = $jj_probe.exit_code == 0 and ($jj_probe.stdout | str trim | is-not-empty)
let root = if $is_jj {
  $jj_probe.stdout | str trim
} else {
  let git_probe = tools try-run [git rev-parse --show-toplevel]
  if $git_probe.exit_code != 0 or ($git_probe.stdout | str trim | is-empty) {
    print -e $"WorktreeCreate: ($cwd) is neither a jj nor a git repository"
    exit 1
  }
  $git_probe.stdout | str trim
}

let target = harness worktrees-dir $"($root | path basename)--($name)"
reuse $target

if $is_jj {
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
  mkdir $target
  tools run-or-die ([jj -R $root workspace add --name $name] ++ $revision ++ [$target])
} else {
  let branch = $"worktree-($name)"
  mkdir ($target | path dirname)
  let res = do { ^git -C $root show-ref --verify --quiet $"refs/heads/($branch)" } | complete
  if $res.exit_code == 0 {
    tools run-or-die [git -C $root worktree add $target $branch]
  } else {
    let base = if ($base_commit | is-empty) { "HEAD" } else { $base_commit }
    tools run-or-die [git -C $root worktree add -b $branch $target $base]
  }
}

# Devenv provisioning: local overrides are gitignored, so a fresh checkout
# lacks them; copy from the main tree. The devenv eval cache is per-tree, so
# the worktree's first wrapped command pays a one-time eval.
if ($cwd | path join "devenv.nix" | path exists) {
  for f in ["devenv.local.nix"] {
    let src = $cwd | path join $f
    if ($src | path exists) { cp $src ($target | path join $f) }
  }
}

print $target
