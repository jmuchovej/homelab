default:
    just --list

setup:
    nix profile install nixpkgs#cachix
    nix profile install nixpkgs#devenv

format disk:
    diskutil eraseDisk MS-DOS GPT {{ disk }}

build-iso disk:
    flake build-install-iso minimal
    fd ".*.iso" ./result/iso -x sudo mv {} ISOs/{/}

switch:
    nh darwin switch -u -j 8 --cores 8

deploy host:
    deploy .#{{ host }}

deploy-all:
    deploy .

[working-directory("mikrotik/")]
topology:
    d2 -w -d -p 7326 topology.d2 topology.png

docs:
    uv run --group docs zensical serve
