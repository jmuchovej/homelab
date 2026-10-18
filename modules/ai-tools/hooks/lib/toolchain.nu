#!/usr/bin/env nu

# Which project toolchain governs a directory, and whether this session is
# already inside it. Called as `toolchain detect`.

# A repo boundary. `.git` is a FILE in a git worktree and `.jj` is absent from
# a plain git checkout, so both are tested for existence, not for being a dir.
def is-boundary [dir: string]: nothing -> bool {
  (($dir | path join ".jj" | path exists) or ($dir | path join ".git" | path exists))
}

# `path expand` on an EMPTY string yields the process cwd, which would then
# compare equal to a detected root and silently mark the session active.
def canon [p: string]: nothing -> string {
  if ($p | is-empty) { "" } else { $p | path expand }
}

# Nearest ancestor of `start` (inclusive) holding `file`, or "" once the repo
# boundary is passed. No output annotation: the `loop` only yields through
# `return`, which the type checker reads as producing nothing.
export def find-up [start: string, file: string] {
  mut dir = $start
  loop {
    if ($dir | path join $file | path exists) { return $dir }
    if (is-boundary $dir) { return "" }
    let parent = $dir | path dirname
    if $parent == $dir { return "" }
    $dir = $parent
  }
}

export def detect [start: string]: nothing -> record {
  # Both roots and the env vars they are compared against are canonicalised:
  # `~/homelab` and `~/Documents/src/…/homelab` are the same tree, and the
  # activator always reports the resolved form.
  let here = canon $start

  let devenv = find-up $here "devenv.nix"
  if ($devenv | is-not-empty) {
    return {
      kind: "devenv"
      root: $devenv
      wrap: "devenv shell -q -- <cmd>"
      active: ((canon ($env.DEVENV_ROOT? | default "")) == $devenv)
    }
  }

  let flake = find-up $here "flake.nix"
  if ($flake | is-not-empty) {
    let envrc = $flake | path join ".envrc" | path exists
    # direnv reports its loaded root as `-<abs path>`.
    let loaded = canon ($env.DIRENV_DIR? | default "" | str replace --regex '^-' '')
    return {
      kind: "flake"
      root: $flake
      wrap: (if $envrc { "direnv exec . <cmd>" } else { "nix develop -c <cmd>" })
      active: (if $envrc { $loaded == $flake } else { ($env.IN_NIX_SHELL? | default "") != "" })
    }
  }

  { kind: "", root: "", wrap: "", active: true }
}
