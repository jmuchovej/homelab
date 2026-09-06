#!/usr/bin/env nu

# Replaces Claude Code's built-in `git worktree` creation for every worktree
# (`--worktree`, `isolation: worktree` subagents, background sessions).
# `.worktreeinclude` is not processed for hook-created worktrees — copy any
# gitignored files here if that is wanted.
#
# Stdout is the path Claude Code adopts as the session's worktree — which may
# differ from the `worktree_path` it proposed. That matters for COLOCATED jj
# repos: a jj workspace has no `.git`, so inside a git checkout its git
# discovery resolves to the MAIN checkout and Claude Code refuses it as an
# isolation worktree ("a checkout discovered above it"). Those workspaces go
# under ~/.claude/worktrees/<repo-slug>/ instead, outside any checkout;
# docs/en/worktrees explicitly supports relocating via the hook's output.

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

# Reusing a name reopens the existing worktree; nothing to create.
def reuse [dir: string] {
  if (($"($dir)/.jj" | path exists) or ($"($dir)/.git" | path exists)) {
    print $dir
    exit 0
  }
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

cd $cwd

let jj_probe = try-run [jj --ignore-working-copy root]
let created = if $jj_probe.exit_code == 0 and ($jj_probe.stdout | str trim | is-not-empty) {
  let root = $jj_probe.stdout | str trim

  # Colocated repo: the workspace must live outside the git checkout (see
  # header). Pure-jj repos have no git discovery to trip, so the proposed
  # in-repo path is fine there.
  let target = if ($"($root)/.git" | path exists) {
    let slug = $"($root | path basename | str replace -ra '[^A-Za-z0-9-]' '-')-($root | hash md5 | str substring 0..<8)"
    [$env.HOME ".claude" "worktrees" $slug $name] | path join
  } else {
    $worktree_path
  }
  reuse $target

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
  run-or-die ([jj -R $root workspace add --name $name] ++ $revision ++ [$target])
  $target
} else {
  let git_probe = try-run [git rev-parse --show-toplevel]
  if $git_probe.exit_code != 0 or ($git_probe.stdout | str trim | is-empty) {
    print -e $"WorktreeCreate: ($cwd) is neither a jj nor a git repository"
    exit 1
  }
  let root = $git_probe.stdout | str trim
  let branch = $"worktree-($name)"
  reuse $worktree_path

  mkdir ($worktree_path | path dirname)
  let res = do { ^git -C $root show-ref --verify --quiet $"refs/heads/($branch)" } | complete
  if $res.exit_code == 0 {
    run-or-die [git -C $root worktree add $worktree_path $branch]
  } else {
    let base = if ($base_commit | is-empty) { "HEAD" } else { $base_commit }
    run-or-die [git -C $root worktree add -b $branch $worktree_path $base]
  }
  $worktree_path
}

# Devenv provisioning: local overrides are gitignored, so a fresh checkout
# lacks them; copy from the main tree. The devenv eval cache is per-tree, so
# the worktree's first wrapped command pays a one-time eval.
if ($cwd | path join "devenv.nix" | path exists) {
  for f in ["devenv.local.nix"] {
    let src = $cwd | path join $f
    if ($src | path exists) { cp $src ($created | path join $f) }
  }
}

print $created
