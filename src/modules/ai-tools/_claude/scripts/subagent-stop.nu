#!/usr/bin/env nu

# Summarize a finished subagent's transcript and send a desktop notification.
# `claude-notify` is provided on PATH by scripts.nix.

let input = open --raw /dev/stdin | from json
let transcript = $input.agent_transcript_path? | default ""

if ($transcript | is-empty) or ($transcript | path type) != "file" { exit 0 }

let raw_lines = open --raw $transcript | lines

# Skip warmup/init tasks (less than 4 lines means no real work done)
if ($raw_lines | length) < 4 { exit 0 }

let rows = $raw_lines
  | each { |l| try { $l | from json } catch { null } }
  | where { |r| ($r | describe) =~ '^record' }

let tool_uses = $rows
  | where { |r| ($r.type? | default "") == "assistant" }
  | each { |r| $r.message?.content? | default [] }
  | flatten
  | where { |c| ($c.type? | default "") == "tool_use" }

let files = $tool_uses
  | where { |t| ($t.name? | default "") in [Edit Write MultiEdit] }
  | each { |t| $t.input?.file_path? | default ($t.input?.filePath? | default "") }
  | where { |p| $p | is-not-empty }
  | uniq
  | length
let bash_count = $tool_uses | where { |t| ($t.name? | default "") == "Bash" } | length
let read_count = $tool_uses | where { |t| ($t.name? | default "") in [Read Glob Grep] } | length
let errors = $rows
  | where { |r| ($r.type? | default "") == "tool_result" }
  | where { |r| ($r.error? | default false) == true or ($r.is_error? | default false) == true }
  | length

let texts = $rows
  | where { |r| ($r.type? | default "") == "assistant" }
  | each { |r| $r.message?.content? | default [] }
  | flatten
  | where { |c| ($c.type? | default "") == "text" }
  | each { |c| $c.text? | default "" }
  | where { |t| $t | is-not-empty }
let last_line = if ($texts | is-empty) { "" } else { $texts | last | split row "\n" | first }
let text = if ($last_line | str length) > 80 {
  ($last_line | str substring 0..<80) + "..."
} else {
  $last_line
}

mut parts = []
if $files > 0 { $parts = ($parts | append $"($files) files") }
if $bash_count > 0 { $parts = ($parts | append $"($bash_count) cmds") }
if $read_count > 0 { $parts = ($parts | append $"($read_count) reads") }
if $errors > 0 { $parts = ($parts | append $"($errors) errs") }

let msg = if ($parts | is-not-empty) {
  $"[($parts | str join ', ')] ($text)"
} else if ($text | is-not-empty) {
  $text
} else {
  "Subagent completed"
}

^claude-notify "Claude Code" $msg
