# Maps both the shorthand (`github`) and the real clone host (`github.com`) to
# the directory under `~/Documents/src`. Generated from the `forges` table in
# `programs/terminal/jujutsu.nix`, so it cannot drift from the jj email scopes or
# git's `insteadOf` rewrites. The `{}` default keeps this file valid standalone.
const FORGES = {} # @@forge-dirs@@

# Clone into `~/Documents/src/{forge}/{owner}/{repo}` and link it into a view.
#
# `~/Documents/{dev,Projects,Research}` are views: symlink farms over the
# canonical tree. A repo already present in `src` is not re-cloned, so adding
# it to a second view costs nothing.
#
# Forks are stored under their *upstream* path, which cannot be derived from a
# `forked-*` URL — clone the upstream and repoint `origin` afterwards.
def main [
  url: string # `forge:owner/repo` shorthand, or any clone URL
  name?: string # link name within the view (default: the repo name)
  --view: string # view directory under `~/Documents` (default: `dev`)
] {
  # Shorthand resolves on the token before the first colon; a real URL falls
  # through to host parsing (strip scheme, userinfo, then path or port).
  let host = ($url
    | str replace -r '^[a-z]+://' ''
    | str replace -r '^[^@/]+@' ''
    | str replace -r '[:/].*$' '')

  let dir = ($FORGES
    | get -o ($url | split row ":" | first)
    | default ($FORGES | get -o $host)
    | default $host)

  # Everything after the host (or the shorthand token) is `owner/repo`.
  let owner_repo = ($url
    | str replace -r '^[a-z]+://' ''
    | str replace -r '^[^@/]+@' ''
    | str replace -r '^[^:/]+[:/]' ''
    | str replace -r '\.git$' '')

  if ($owner_repo | path basename | str starts-with "forked-") {
    print -e $"warning: ($owner_repo) is a fork; the canonical path is the upstream"
    print -e "         owner. Clone the upstream URL, then repoint `origin` at the fork."
  }

  let dest = ([$nu.home-dir Documents src $dir $owner_repo] | path join)

  if ($dest | path exists) {
    print $"present: ($dest)"
  } else {
    mkdir ($dest | path dirname)
    ^jj git clone --colocate $url $dest
  }

  # Link only when asked: `--view` alone, or a bare name (which means `dev`).
  let target = if $view != null {
    $view
  } else if $name != null {
    "dev"
  } else {
    null
  }

  if $target == null {
    print "no link created; pass a name or --view to add one"
    return
  }

  let alias = ([$nu.home-dir Documents $target ($name | default ($dest | path basename))] | path join)

  if ($alias | path exists) {
    print -e $"warning: ($alias) already exists; leaving it alone"
  } else {
    mkdir ($alias | path dirname)
    ^ln -s $dest $alias
    print $"linked ($alias) -> ($dest)"
  }
}
