# Desktop notifications for any harness.
#
# Title, macOS sender, and icon come from `harness` (lib/harness.nu), i.e.
# from the harness aspect's Nix. Icons live under ./assets as
# `<icon>.png` plus `-dark`/`-light` variants chosen from the system
# appearance at run time. The model is shown as the subtitle when the caller
# can name it; `model-of` derives it from a hook payload.

use ./harness.nu *

# Resolved at parse time against this module's own location, so it survives
# the copy into the store.
const ASSETS = (path self ./assets)

# "dark", "light", or "" when the appearance cannot be determined.
def appearance []: nothing -> string {
  let host = sys host | get name
  if $host == "Darwin" {
    # Prints "Dark" in dark mode and fails in light mode.
    let style = do { ^defaults read -g AppleInterfaceStyle } | complete
    if $style.exit_code == 0 and ($style.stdout | str trim) == "Dark" { "dark" } else { "light" }
  } else if (which gsettings | is-not-empty) {
    let scheme = do { ^gsettings get org.gnome.desktop.interface color-scheme } | complete
    if $scheme.exit_code == 0 and ($scheme.stdout =~ "dark") { "dark" } else { "light" }
  } else {
    ""
  }
}

# The themed icon if present, else the theme-neutral mark, else "" (no icon).
def icon-for [icon: string]: nothing -> string {
  if ($icon | is-empty) { return "" }
  let variant = appearance
  let themed = $ASSETS | path join $"($icon)-($variant).png"
  let plain = $ASSETS | path join $"($icon).png"
  if ($variant | is-not-empty) and ($themed | path exists) {
    $themed
  } else if ($plain | path exists) {
    $plain
  } else {
    ""
  }
}

# Model of the last assistant turn in a JSONL transcript, or "".
export def model-from-transcript [path: string]: nothing -> string {
  if ($path | is-empty) or ($path | path type) != "file" { return "" }
  let turns = open --raw $path
    | lines
    | reverse
    | each { |l| try { $l | from json } catch { null } }
    | where { |r| ($r | describe) =~ '^record' and ($r.type? | default "") == "assistant" }
  if ($turns | is-empty) { "" } else { $turns | first | get message?.model? | default "" }
}

# Best-effort model name for a hook payload: a `model` field (status-line
# style, or a plain string), else the transcript the payload names.
export def model-of [input: record]: nothing -> string {
  let direct = $input.model?.display_name? | default ($input.model? | default "")
  let direct = if ($direct | describe) == "string" { $direct } else { "" }
  if ($direct | is-not-empty) {
    $direct
  } else {
    model-from-transcript ($input.agent_transcript_path? | default ($input.transcript_path? | default ""))
  }
}

# Send a desktop notification for the current harness. Named `main` because
# a module may not export a command named after itself; through `use lib *`
# it is called as `notify`.
export def main [
  message: string        # notification body
  --model: string = ""   # shown as the subtitle when non-empty
  --dry-run              # print the command instead of running it
] {
  let identity = harness
  let icon = icon-for $identity.icon

  let argv = if (sys host | get name) == "Darwin" {
    if (which terminal-notifier | is-empty) {
      [osascript -e $"display notification \"($message)\" with title \"($identity.app)\""]
    } else {
      [terminal-notifier -title $identity.app -message $message -sound default]
        | append (if ($icon | is-not-empty) { [-appIcon $icon] } else { [] })
        | append (if ($model | is-not-empty) { [-subtitle $model] } else { [] })
        | append (if ($identity.sender | is-not-empty) { [-sender $identity.sender] } else { [] })
    }
  } else {
    let summary = if ($model | is-not-empty) { $"($identity.app) · ($model)" } else { $identity.app }
    [notify-send -a $identity.app]
      | append (if ($icon | is-not-empty) { [-i $icon] } else { [] })
      | append [$summary $message]
  }

  if $dry_run {
    print ($argv | str join " ")
  } else {
    run-external ...$argv
  }
}
