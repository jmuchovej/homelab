# components/ — reusable cross-app building blocks

Two shapes live here, and the distinction matters:

- **Shared-path Kustomization** (`cnpg-database`): a plain
  `kustomize.config.k8s.io/v1beta1` Kustomization. Per-app Flux Kustomizations
  point `spec.path` directly at the directory — no per-app overlay dir, no
  `../../../../components` relative pathing.
- **Overlay Component** (`cnpg-import`): a true Kustomize `Component`
  (`v1alpha1`), layered onto a shared path via the Flux Kustomization's
  `spec.components`. Entries there resolve relative to `spec.path`, so a
  sibling is `../<name>`.

Neither shape has native inputs — every `${VAR}` in the manifests is
substituted by Flux `postBuild.substitute` in the **consuming** app's
`*.ks.yaml`. Attaching is therefore a one-file affair: the app's ks sets
`path`, optional `components`, the `substitute` vars, `targetNamespace`, and
`dependsOn`. Canonical example: `apps/auth/authentik/authentik-db.ks.yaml`.

Manifests here carry only load-bearing comments (root documentation policy);
each directory's `AGENTS.md` holds its parameters and rationale:

- `cnpg-database/` — per-app postgres (CNPG `Cluster` + creds + NetworkPolicy)
- `cnpg-import/` — one-off migration of an app's DB from the NixOS postgres

## Adding a building block

kebab-case directory; an `AGENTS.md` with a parameters table + rationale;
SCREAMING_SNAKE `${VAR}` parameters. Pick the shape: plain Kustomization when
apps consume it whole as their `spec.path`; `Component` when it layers onto
another path.
