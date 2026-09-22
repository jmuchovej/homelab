#!/usr/bin/env nu

# Notification hook: surface the harness's attention request on the desktop.
# Claude's Notification payload carries `message`; other harnesses may not,
# hence the default. All the work is in lib/notify.nu.

use lib *

def main [
  --dry-run   # print the command instead of notifying
] {
  let input = tools payload
  let message = $input.message? | default "Awaiting your input"
  let model = notify model-of $input
  if $dry_run { notify $message --model $model --dry-run } else { notify $message --model $model }
}
