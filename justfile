set script-interpreter := ["bash", "-euo", "pipefail"]
set default-list

mod k8s "kubernetes/justfile"
mod bootstrap "bootstrap/justfile"
mod mikrotik "tofu/mikrotik.just"
mod authentik "tofu/authentik.just"
mod tofu "tofu/justfile"
mod nix "modules/justfile"

setup:
    nix profile install nixpkgs#cachix

[macos]





[working-directory("mikrotik/")]
topology:
    d2 -w -d -p 7326 topology.d2 topology.png
