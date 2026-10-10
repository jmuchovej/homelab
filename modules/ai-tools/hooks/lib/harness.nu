# Which harness these hooks belong to.
#
# `mk-nu-script` writes the harness aspect's `harness` attrset to a JSON file
# and names it in $HARNESS_DETAILS, so the identity lives once, in
# `ai-tools/<harness>.nix`. Fields:
#   name    the harness id; also the `~/.local/share/<name>` and
#           `~/Documents/dev/worktrees/_<name>` suffix
#   app     display title for notifications
#   icon    base name under lib/assets (`<icon>{,-dark,-light}.png`)
#   sender  macOS bundle id whose icon Notification Center shows, or ""

const DEFAULTS = { name: "agent", app: "Agent", icon: "", sender: "" }

def details []: nothing -> record {
  if ("HARNESS_DETAILS" in $env) { $DEFAULTS | merge (open $env.HARNESS_DETAILS) } else { $DEFAULTS }
}

# The identity record. Named `main` because a module may not export a command
# named after itself; through `use lib *` it is called as `harness`.
export def main []: nothing -> record {
  details
}

# `$XDG_DATA_HOME/<harness name>`, joined with any further segments.
export def data-dir [...segments: string]: nothing -> string {
  $env.XDG_DATA_HOME | path join (details).name ...$segments
}

# `~/Documents/dev/worktrees/_<harness name>`, joined with any further segments.
export def worktrees-dir [...segments: string]: nothing -> string {
  $env.HOME | path join "Documents/dev/worktrees" $"_((details).name)" ...$segments
}
