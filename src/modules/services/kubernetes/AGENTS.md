# modules/services/kubernetes

`@marker@` substitution over a static YAML file — the schema stays with the YAML (`$schema` modeline + kubeconform below); Nix only fills values. `sops` placeholders are ordinary eval-time strings, so secrets need no separate mechanism.

Schemas are vendored in `manifests/schemas/`.

schemas are VENDORED (manifests/schemas/, refreshed by `just k8s update-schemas`) — the sandbox has no network, and the same files back the editor's relative `# $schema:` comments, so editor and build always validate against identical schemas. The `linkFarm` layout must match the two-schema-location templates below; a new kind in the bootstrap manifests fails the check until its schema is vendored.
