mod bootstrap "src/modules/hosts/bootstrap/justfile"

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

[working-directory("mikrotik/")]
topology:
    d2 -w -d -p 7326 topology.d2 topology.png

docs:
    uv run --group docs zensical serve
