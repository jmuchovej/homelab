{
  inputs,
  cilium-manifest,
  flux-instance-manifest,
  pkgs,
  ...
}:
let
  k8s-schemas = pkgs.linkFarm "k8s-bootstrap-schemas" [
    {
      name = "fluxcd.controlplane.io/fluxinstance_v1.json";
      path = "${inputs.self}/vendor/schemas/fluxinstance_v1.json";
    }
    {
      name = "helm.cattle.io/helmchart_v1.json";
      path = "${inputs.self}/vendor/schemas/helmchart_v1.json";
    }
    {
      name = "namespace-v1.json";
      path = "${inputs.self}/vendor/schemas/namespace-v1.json";
    }
  ];
in
# every bootstrap manifest — static and template-rendered — must
# satisfy its schema for the system to build. Secrets are skipped
# (kubeconform can't see through sops placeholders anyway); the
# pre-commit hook covers kubernetes/ only, not these.
pkgs.runCommand "check-k8s-bootstrap-manifests"
  {
    nativeBuildInputs = with pkgs; [
      kubeconform
      check-jsonschema
      yq-go
    ];
  }
  ''
    kubeconform -strict -skip Secret \
      -schema-location '${k8s-schemas}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
      -schema-location '${k8s-schemas}/{{.ResourceKind}}{{.KindSuffix}}.json' \
      -summary \
      ${cilium-manifest} \
      ${./flux-operator.yaml} \
      ${flux-instance-manifest}

    check-jsonschema \
      --schemafile ${inputs.self}/vendor/schemas/cilium-values.json \
      ${./cilium-values.yaml}

    # the vendored schema must have been refreshed for the pinned
    # chart version, or values validate against a stale schema
    want=$(yq 'select(.kind == "HelmChart") | .spec.version' ${cilium-manifest})
    have=$(yq -p json '."cilium-values.json".version' ${inputs.self}/vendor/schemas/SOURCES.json)
    if [ "$want" != "$have" ]; then
      echo "cilium chart $want but vendored values schema is for $have —" \
        "run 'just k8s update-schemas'" >&2
      exit 1
    fi
    touch "$out"
  ''
