# Nearest ancestor of `start` (inclusive) holding a `devenv.nix` file, or "".
# Called as `devenv find-root`. No output annotation: the `loop` only yields
# through `return`, which the type checker reads as producing nothing.
export def find-root [start: string] {
  mut dir = $start
  loop {
    if ($dir | path join "devenv.nix" | path type) == "file" { return $dir }
    let parent = $dir | path dirname
    if $parent == $dir { return "" }
    $dir = $parent
  }
}
