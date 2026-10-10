## Purpose

Defines the shape of the configuration-phase OpenTofu root module under `tofu/` — which top-level files exist and what each owns, where provider configuration lives, how a datacenter site is added, and when one-shot blocks are retired — so that adding a site is a bounded edit and a plan never carries blocks that no longer do anything.
The bootstrap-phase root module under `bootstrap/` is a separate root governed by the `repo-layout` lifecycle-phase requirement and is outside this capability.

## ADDED Requirements

### Requirement: The root module has a bounded top-level file set

The configuration-phase OpenTofu root module SHALL consist of exactly these top-level files in `tofu/`: `main.tofu`, `holonet.tofu`, `cloudflare.tofu`, `authentik.tofu`, and one `<site>.tofu` per datacenter site.
Every other configuration-phase OpenTofu source file SHALL live under `tofu/` inside a child module directory.
Each top-level file SHALL own one job: `main.tofu` the backend, provider requirements, provider blocks, sops reads, and the domain locals; `holonet.tofu` the overlay catalog, the overlay DNS records, and the ZeroTier network; `cloudflare.tofu` the zone and site-agnostic tunnels; `authentik.tofu` the authentik module instance; `<site>.tofu` that site's module instances only.
The R2 state bucket and its lifecycle and lock rules are NOT owned here: they are provisioned by the bootstrap-phase root module, which holds the account-level credential that editing bucket configuration requires.

#### Scenario: Top-level listing is bounded

- **WHEN** `tofu/` is listed for `*.tofu` files
- **THEN** the result is exactly `main.tofu`, `holonet.tofu`, `cloudflare.tofu`, `authentik.tofu`, and one `<site>.tofu` per site, and nothing else

#### Scenario: A site file holds only that site

- **WHEN** a `<site>.tofu` file is read
- **THEN** every module instance in it is bound to that site's provider aliases or names that site in its identity, it declares no `provider` block and no resource of its own, and no instance for another site appears in it

### Requirement: Provider configuration has one home

`provider` blocks SHALL appear only in `main.tofu`, including every aliased RouterOS and Kubernetes provider.
Site files and child modules SHALL reference provider aliases, never declare them.
Sops inputs that differ only by file name SHALL be read by a single `for_each` data source rather than one data source per file.

#### Scenario: No provider block outside main

- **WHEN** every top-level file other than `main.tofu` is searched for `provider` blocks
- **THEN** there are zero matches, and every provider alias referenced by a module instance in those files is declared in `main.tofu`

#### Scenario: Adding a relay adds no data source

- **WHEN** a relay is added to `topology.yaml` and its host sops file is created
- **THEN** its credentials are read without adding a `sops_file` data source, and only its `provider` alias and module instance are new

### Requirement: Shared behavior lives in child modules, instanced per site

Resources that every site needs in the same shape SHALL be declared once in a child module under `tofu/` and instanced once per site from that site's `<site>.tofu`.
A child module SHALL exist only where it owns resources or data sources for more than one call site; a module that only forwards inputs to another module SHALL NOT exist.
A child module SHALL receive its providers through the module's `providers` map, so that a per-site instance differs from another site's only by its inputs and provider aliases.

#### Scenario: A new site is a site file

- **WHEN** a third datacenter site is added
- **THEN** the work is one new `<site>.tofu`, its provider aliases in `main.tofu`, and its sops files, and no child module changes

#### Scenario: Per-site discovery is a module instance

- **WHEN** the authentik-enabled HTTPRoutes of a site are discovered
- **THEN** the discovery runs in a child module instance bound to that site's Kubernetes provider, and the root module contains no per-site discovery data source

#### Scenario: Site DNS records are owned by the module that knows the target

- **WHEN** a site's public apex and wildcard records are declared
- **THEN** they are created by the child module instance that owns the target they point at, and no site file declares a DNS record directly

### Requirement: One-shot blocks do not accumulate

An `import` or `moved` block SHALL be deleted once every address it targets is present in state, and that deletion SHALL be verified by a plan that reports no changes for those addresses.
A `moved` block SHALL be used, not a destroy-and-create, whenever a resource changes address within this root module.

#### Scenario: Applied one-shot blocks are removed

- **WHEN** every address targeted by an `import` or `moved` block is listed by `tofu state list`
- **THEN** the block is removed before the change that applied it is archived, and the next plan still reports no changes for those addresses

#### Scenario: A missing target stops the retirement

- **WHEN** an `import` or `moved` target is absent from `tofu state list`
- **THEN** that block is kept and the discrepancy is reported before any other block is deleted

#### Scenario: Address changes do not replace resources

- **WHEN** a resource moves from a root address into a child module address
- **THEN** the plan shows a move for that resource and no destroy or create

### Requirement: The authentik discovery file is optional to plan

The authentik permission map written by `just authentik discover-all` SHALL be read by the authentik child module from its known path, and SHALL NOT be a root-module variable.
A plan SHALL succeed with that file absent, passing permission codenames through unmapped.

#### Scenario: Plan without the discovery file

- **WHEN** `tofu/authentik.auto.tfvars.json` is absent
- **THEN** `tofu plan` still succeeds, and the only diffs it may show are permission codenames on role resources

#### Scenario: Plan with the discovery file

- **WHEN** `just authentik discover-all` has written `tofu/authentik.auto.tfvars.json`
- **THEN** the plan maps permission codenames through it and reports no changes on role resources
