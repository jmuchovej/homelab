mod bootstrap "src/modules/hosts/bootstrap/justfile"
mod mikrotik "src/terraform/mikrotik.just"
mod authentik "src/terraform/authentik.just"

[private]
default:
    just --list

setup:
    nix profile install nixpkgs#cachix

format disk:
    diskutil eraseDisk MS-DOS GPT {{ disk }}

[linux]
switch:
    nh os switch . -j 8 --cores 8

[macos]
switch:
    nh darwin switch . -j 8 --cores 8

regen:
    nix run .#write-flake

update: regen
    nix flake update

deploy host *ARGS:
    deploy .#{{ host }} {{ ARGS }}

deploy-all:
    deploy .

# Capture a host's nixos-facter hardware report into the repo, no git needed on
# the host. `nix run` fetches facter on the fly (it isn't installed until a host
# already has a report), and `doas` is the servers' passwordless privilege tool.
# Usage: just facter da-vcx-2 [ssh-target]   (ssh-target defaults to the host name)
facter host target=host:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="src/modules/hosts/{{ host }}"
    [ -d "$dir" ] || { echo "no such host dir: $dir" >&2; exit 1; }
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    echo ">> scanning {{ target }} with nixos-facter (via doas)…" >&2
    ssh "lab@{{ target }}" 'doas nix run nixpkgs#nixos-facter' >"$tmp"
    [ -s "$tmp" ] && yq -p json '.' "$tmp" >/dev/null || { echo "!! invalid/empty report; not written" >&2; exit 1; }
    mv "$tmp" "$dir/facter.json"
    echo ">> wrote $dir/facter.json ($(wc -c <"$dir/facter.json" | tr -d ' ') bytes)" >&2

[working-directory("mikrotik/")]
topology:
    d2 -w -d -p 7326 topology.d2 topology.png

docs:
    uv run --group docs zensical serve
