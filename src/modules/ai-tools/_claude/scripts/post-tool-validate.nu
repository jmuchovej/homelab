#!/usr/bin/env nu

let input = open --raw /dev/stdin | from json
let filepath = $input.tool_input?.file_path? | default ""

if ($filepath | is-not-empty) and ($filepath | path type) == "file" {
  let size = ls $filepath | first | get size
  if $size > 1mb {
    {
      additionalContext: $"Warning: Large file written \(($size | into int) bytes\) to ($filepath)"
    } | to json -r | print
  }
}

exit 0
