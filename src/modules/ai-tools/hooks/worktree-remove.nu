#!/usr/bin/env nu

def try-run [args: list<string>] {
  let res = do { ^($args | first) ...($args | skip 1) } | complete
  if ($res.stderr | is-not-empty) { print -e ($res.stderr | str trim) }
  $res
}

let input = open --raw /dev/stdin | from json
let worktree_path = $input.worktree_path? | default ""

if ($worktree_path | is-empty) { exit 0 }
if not ($worktree_path | path exists) { exit 0 }

# A main checkout has `.git` as a directory; a git worktree has it as a
# file and a jj workspace has neither. Never rm -rf the former.
if ($"($worktree_path)/.git" | path type) == "dir" {
  print -e $"WorktreeRemove: refusing ($worktree_path), it looks like a main checkout"
  exit 0
}

if ($"($worktree_path)/.jj" | path exists) {
  # Forget defaults to the workspace named by -R, so no name bookkeeping.
  # It only drops the repo's record; the directory is ours to delete.
  try-run [jj -R $worktree_path --ignore-working-copy workspace forget] | ignore
  rm -rf $worktree_path
} else if ($"($worktree_path)/.git" | path exists) {
  let listing = try-run [git -C $worktree_path worktree list --porcelain]
  let mains = $listing.stdout
    | lines
    | where ($it | str starts-with "worktree ")
    | each { str substring 9.. }
  if $listing.exit_code == 0 and ($mains | is-not-empty) {
    let main = $mains | first
    let removed = try-run [git -C $main worktree remove --force $worktree_path]
    if $removed.exit_code != 0 { rm -rf $worktree_path }
    try-run [git -C $main worktree prune] | ignore
  } else {
    rm -rf $worktree_path
  }
} else {
  rm -rf $worktree_path
}
