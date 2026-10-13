---
paths:
  - "modules/services/kubernetes/**"
---

# modules/services/kubernetes

`@marker@` substitution over a static YAML file — the schema stays with the YAML (`$schema` modeline + kubeconform below); Nix only fills values.
`sops` placeholders are ordinary eval-time strings, so secrets need no separate mechanism.

The seed manifests and `checks.nix` live in `bootstrap/kubernetes/`, read by path through `inputs.self`; their layout, the k3s/Talos seam, schema vendoring, and what may be auto-imported from `bootstrap/` are in `bootstrap/AGENTS.md`.
`render-yaml` comes from `lib.rbn` (`_lib/yaml.nix`).

This directory holds no bootstrap-phase tooling: `update-schemas` lives in `bootstrap/<target>/justfile` and the kubeconfig sync in `kubernetes/justfile`, so there is no justfile here.
The one thing this aspect owes the check is `k3s-version`, passed from `config.services.k3s.package.version` at the `checks.nix` call site so the ratchet measures the k3s this host actually deploys.
