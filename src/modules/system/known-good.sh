#!/usr/bin/env bash
# known-good — pin/unpin bootable "known good" NixOS system generations.
#
# Each pin becomes its own profile under /nix/var/nix/profiles/system-profiles,
# which (a) roots the closure so `nix-collect-garbage --delete-older-than` can't
# collect it, and (b) makes NixOS's systemd-boot builder emit a dedicated menu
# entry for it. So a pinned generation survives the weekly GC AND stays bootable
# as a fallback — unlike ordinary system-profile generations, which the 7-day GC
# shreds.

profiles=/nix/var/nix/profiles
pindir="$profiles/system-profiles"

usage() {
  cat <<'EOF'
known-good — pin/unpin bootable "known good" NixOS generations

Usage:
  known-good pin [GEN]     Pin GEN (default: the current system generation)
  known-good unpin GEN     Remove the pin for GEN
  known-good list          List pinned generations
  known-good boot          Regenerate boot entries (rarely needed by hand)

Pin ONLY after you've confirmed the generation boots cleanly. A pin cannot
recover a generation the GC has already collected. Mutating commands re-exec
themselves under sudo.
EOF
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
  fi
}

current_gen() {
  local t
  t=$(readlink "$profiles/system")
  t=${t#system-}
  t=${t%-link}
  printf '%s\n' "$t"
}

resolve_toplevel() {
  local gen="$1"
  local link="$profiles/system-$gen-link"
  if [ ! -e "$link" ]; then
    printf 'known-good: generation %s not found (%s)\n' "$gen" "$link" >&2
    printf 'known-good: it may have already been garbage-collected.\n' >&2
    exit 1
  fi
  readlink -f "$link"
}

regen_boot() {
  printf 'known-good: regenerating boot entries...\n'
  "$profiles/system/bin/switch-to-configuration" boot
}

do_pin() {
  local gen="${1:-}"
  [ -n "$gen" ] || gen=$(current_gen)
  local top
  top=$(resolve_toplevel "$gen")
  mkdir -p "$pindir"
  nix-env -p "$pindir/known-good-$gen" --set "$top"
  printf 'known-good: pinned generation %s (%s)\n' "$gen" "$top"
  regen_boot
}

do_unpin() {
  local gen="${1:-}"
  if [ -z "$gen" ]; then
    printf 'known-good: usage: known-good unpin <gen>\n' >&2
    exit 1
  fi
  rm -f "$pindir/known-good-$gen" "$pindir/known-good-$gen"-*-link
  printf 'known-good: unpinned generation %s\n' "$gen"
  regen_boot
}

do_list() {
  local p found=0
  for p in "$pindir"/known-good-*; do
    [ -L "$p" ] || continue
    case "$p" in *-link) continue ;; esac
    found=1
    printf '%s -> %s\n' "${p##*/}" "$(readlink -f "$p")"
  done
  [ "$found" -eq 1 ] || printf 'known-good: no pinned generations.\n'
}

main() {
  local sub="${1:-help}"
  case "$sub" in
  pin)
    need_root "$@"
    shift
    do_pin "${1:-}"
    ;;
  unpin)
    need_root "$@"
    shift
    do_unpin "${1:-}"
    ;;
  boot)
    need_root "$@"
    regen_boot
    ;;
  list) do_list ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
  esac
}

main "$@"
