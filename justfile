set script-interpreter := ["bash", "-euo", "pipefail"]
mod bootstrap "bootstrap/justfile"
mod mikrotik "tofu/mikrotik.just"
mod authentik "tofu/authentik.just"

[private]
default:
    just --list

setup:
    nix profile install nixpkgs#cachix

[private]
nh-switch os *ARGS:
    nh {{ os }} switch . --max-jobs $(nproc) --cores $(nproc) {{ ARGS }}

[linux]
switch *ARGS:
    @just nh-switch os {{ ARGS }}

[macos]
switch *ARGS:
    @just nh-switch darwin {{ ARGS }}

regen:
    nix run .#write-flake

update: regen
    nix flake update

deploy host *ARGS:
    deploy .#{{ host }} {{ ARGS }}

deploy-all:
    deploy .

[working-directory("mikrotik/")]
topology:
    d2 -w -d -p 7326 topology.d2 topology.png
