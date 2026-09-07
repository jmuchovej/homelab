#!/usr/bin/env nu

# Renames a bridge session's jj workspace after the task it is running.
#
# Claude Code names bridge-launched worktrees `bridge-cse_<cloud session id>`
# (hardcoded, no setting), and nothing about the task is known when the
# WorktreeCreate hook fires. So the label is applied afterwards, from
# UserPromptSubmit and Stop, once the transcript can say what the session is
# about. The workspace NAME carries the label: Claude Code only tracks the
# directory path, so renaming is invisible to it, and unlike a commit
# description or a bookmark the name does not stay behind when the working
# copy moves.
#
# Label sources, best first: a custom title (/rename), the AI-generated title,
# the first user prompt. A name set from a lesser source is upgraded when a
# better one shows up; anything else is left alone. The directory keeps the
# opaque id, and its last four characters suffix every label so names stay
# unique and traceable back to the directory.
#
# Never writes to stdout: for UserPromptSubmit that would land in the model's
# context. Commands go through `tools run-quiet`, which also keeps their stderr.

use lib *

# Lowercase, hyphen-joined, cut at a word boundary within 40 chars.
def slugify [text: string] {
  let slug = $text
    | str replace -ra '<[^>]*>' ' '
    | str lowercase
    | str replace -ra '[^a-z0-9]+' '-'
    | str trim -c '-'
  if ($slug | str length) > 40 {
    $slug | str substring 0..<40 | str replace -r '-[^-]*$' ''
  } else {
    $slug
  }
}

# Text of a user row: plain string content, or its first text block.
# Tool results are user rows too, but carry no text block.
def prompt-text [row: record] {
  let content = $row.message?.content? | default ""
  if ($content | describe) == "string" {
    $content
  } else {
    $content
      | where { |c| ($c.type? | default "") == "text" }
      | each { |c| $c.text? | default "" }
      | append ""
      | first
  }
}

# Field of the latest transcript row of the given type, or "".
def last-title [rows: list, type: string, field: string] {
  $rows
    | where { |r| ($r.type? | default "") == $type }
    | each { |r| $r | get -o $field | default "" }
    | prepend ""
    | last
}

let input = open --raw /dev/stdin | from json
let cwd = if ($input.cwd? | is-empty) { $env.PWD } else { $input.cwd }
cd $cwd

let root_probe = tools run-quiet [jj --ignore-working-copy workspace root]
if $root_probe.exit_code != 0 { exit 0 }
let root = $root_probe.stdout | str trim
let opaque = $root | path basename
if not ($opaque =~ '^bridge-') { exit 0 }
let suffix = $opaque | split chars | last 4 | str join

# `@` resolves per workspace, so `working_copies` names this one.
let name_probe = tools run-quiet [jj -R $root --ignore-working-copy --color never log -r @ --no-graph -T working_copies]
if $name_probe.exit_code != 0 { exit 0 }
let current = $name_probe.stdout | str trim | split row " " | first | str trim -r -c "@"

let transcript = $input.transcript_path? | default ""
let rows = if ($transcript | path type) == "file" {
  open --raw $transcript
    | lines
    | each { |l| try { $l | from json } catch { null } }
    | where { |r| ($r | describe) =~ '^record' }
} else {
  []
}

let custom = if ($input.session_title? | is-empty) {
  last-title $rows "custom-title" "customTitle"
} else {
  $input.session_title
}
let ai = last-title $rows "ai-title" "aiTitle"
let first_prompt = $rows
  | where { |r| ($r.type? | default "") == "user" and not ($r.isSidechain? | default false) }
  | each { |r| prompt-text $r }
  | where { |t| $t | str trim | is-not-empty }
  | append ""
  | first

# On UserPromptSubmit the transcript may not hold the prompt yet, and a slash
# command's transcript row can differ from the raw prompt, so both are
# candidates at the lowest rank.
let candidates = [$custom $ai $first_prompt ($input.prompt? | default "")]
  | each { |t| slugify $t }
  | where { |s| $s | is-not-empty }
  | each { |s| $"($s)-($suffix)" }
  | uniq
if ($candidates | is-empty) { exit 0 }

let desired = $candidates | first
if $current == $desired { exit 0 }
# Only replace the opaque name or a label from a lesser source.
if $current != $opaque and not ($current in ($candidates | skip 1)) { exit 0 }

# jj refuses to rename under --ignore-working-copy; it snapshots first.
let res = tools run-quiet [jj -R $root --color never workspace rename $desired]
if $res.exit_code != 0 {
  print -e $"worktree-rename: ($res.stderr | str trim)"
}
