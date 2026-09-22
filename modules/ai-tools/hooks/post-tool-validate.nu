#!/usr/bin/env nu

use lib *

let input = tools read-input
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
