{
  cilium-manifest,
  flux-instance-manifest,
  k3s-version,
  pkgs,
  ...
}:
let
  k8s-schemas = pkgs.linkFarm "k8s-bootstrap-schemas" [
    {
      name = "fluxcd.controlplane.io/fluxinstance_v1.json";
      path = ./schemas/fluxinstance_v1.json;
    }
    {
      name = "helm.cattle.io/helmchart_v1.json";
      path = ./schemas/helmchart_v1.json;
    }
    {
      name = "namespace-v1.json";
      path = ./schemas/namespace-v1.json;
    }
  ];

  # k3s versions itself `<kube-version>+k3sN`; the API schema set is published
  # under the upstream Kubernetes version alone.
  kube-version = pkgs.lib.head (pkgs.lib.splitString "+" k3s-version);
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
      --schemafile ${./schemas/cilium-values.json} \
      ${./cilium-values.yaml}

    # the vendored schema must have been refreshed for the pinned
    # chart version, or values validate against a stale schema
    want=$(yq 'select(.kind == "HelmChart") | .spec.version' ${cilium-manifest})
    have=$(yq -p json -o yaml '."cilium-values.json".version' ${./schemas/SOURCES.json})
    if [ "$want" != "$have" ]; then
      echo "cilium chart $want but vendored values schema is for $have —" \
        "run 'just bootstrap k8s update-schemas'" >&2
      exit 1
    fi

    # the same ratchet for the API schemas: they are vendored for whatever
    # Kubernetes the deployed k3s ships, so a nixpkgs bump that moves k3s
    # has to be followed by a refresh or Namespace validates against a
    # schema the cluster no longer serves
    have_kube=$(yq -p json -o yaml '."namespace-v1.json".version' ${./schemas/SOURCES.json})
    if [ "${kube-version}" != "$have_kube" ]; then
      echo "k3s ships kubernetes ${kube-version} but vendored API schemas are for $have_kube —" \
        "run 'just bootstrap k8s update-schemas'" >&2
      exit 1
    fi
    touch "$out"
  ''
