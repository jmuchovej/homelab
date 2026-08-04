# modules/services/kubernetes

`@marker@` substitution over a static YAML file — the schema stays with the YAML (`$schema` modeline + kubeconform below); Nix only fills values. `sops` placeholders are ordinary eval-time strings, so secrets need no separate mechanism.

The seed manifests live in `src/bootstrap/kubernetes/` (alongside `checks.nix`),
not under this aspect — `src/bootstrap/` is outside the flake's `import-tree
./src/modules` walk, so anything there is inert data and can never be picked up
as an aspect. `render-yaml` comes from `lib.rbn` (`_lib/yaml.nix`).

Schemas are VENDORED at repo-root `vendor/schemas/` (refreshed by `just k8s
update-schemas`) — the sandbox has no network, and the same files back the
manifests' relative `# $schema: ../../../vendor/schemas/…` comments, so editor
and build always validate against identical schemas. The `linkFarm` layout must
match the two-schema-location templates in `checks.nix`; a new kind in the
bootstrap manifests fails the check until its schema is vendored.
