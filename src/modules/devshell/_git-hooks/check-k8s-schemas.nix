# kubeconform changed manifests against the k8s-schemas catalog (same one
# .zed/settings.json maps for the editor). Catches wrong/unknown fields at
# commit time — BEFORE a push turns them into a stalled dependency wave.
{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "check-k8s-schemas";
  runtimeInputs = with pkgs; [
    fluxcd
    kubeconform
  ];
  text = ''
    # dummies for cluster-side postBuild substitution — shaped to satisfy the
    # schemas (hostname/CIDR/quantity patterns). `envsubst --strict` makes
    # any variable missing from this list a loud failure, not a silent
    # pass-through.
    export DATACENTER=dc
    export DC_DOMAIN=dc.example.com
    export DOMAIN=example.com
    export ADMIN_CIDR=10.0.0.0/16
    export APP=app
    export DB_SIZE=1Gi
    export HOST=10.0.0.1
    export DB_LB_IP=10.0.0.2

    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/kubeconform"
    mkdir -p "$cache"

    fail=0
    for f in "$@"; do
      if ! flux envsubst --strict <"$f" |
        kubeconform -strict -skip Secret \
          -cache "$cache" \
          -schema-location default \
          -schema-location 'https://k8s-schemas.home-operations.com/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
          -ignore-missing-schemas; then
        echo "✗ $f"
        fail=1
      fi
    done
    exit "$fail"
  '';
}
