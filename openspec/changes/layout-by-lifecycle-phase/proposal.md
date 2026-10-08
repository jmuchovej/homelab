## Why

`bootstrap/AGENTS.md` already states the placement rule and the repo already follows it — "everything that takes a target from bare metal or factory state to the point where its everyday tool takes over lives here, one directory per target", with a **Hands off to** column naming the tool that takes over (`nix/` → `deploy`/`nh`, `kubernetes/` → Flux, `mikrotik/` → OpenTofu, `talos/` → Flux in the guest).
The `repo-layout` spec never captured that rule, and one of its requirements now contradicts it: "OpenTofu lives under `tofu/`" forbids `bootstrap/` holding an OpenTofu root module, which is exactly what provisioning the R2 state bucket and minting scoped API tokens needs.

The rule is also only written from `bootstrap/`'s side.
Stated once, cross-cutting, it answers where a new tool goes without re-litigating it per tool.

## What Changes

- The `repo-layout` capability gains a requirement stating the principle: **tooling that acts on infrastructure is placed by lifecycle phase.**
  Getting a target from bare metal or factory state to where its everyday tool can configure it belongs under `bootstrap/<target>/`; configuring a target that is already configurable belongs in the tree of **the tool doing the configuring** — Kubernetes manifests under `kubernetes/`, Nix under `modules/` and `packages/`, Hubitat drivers and apps under `hubitat/`, and anything manageable by OpenTofu under `tofu/`.
- **The tree follows the configuring tool, never the configured target.** OpenTofu configuration appears only under `tofu/` or `bootstrap/` and nowhere else, so there is no `kubernetes/main.tofu` and no `modules/main.tofu`. The MikroTik relays and Authentik are both configured by OpenTofu and are therefore declared under `tofu/`, regardless of whether a tree named for them exists elsewhere — `mikrotik/` holds topology diagrams and reference documents, which are not tooling and are outside this principle entirely.
- The principle is **scoped to infra-acting tooling**, so it does not implicate `docs/`, `assets/`, `mikrotik/`, `src/`, `secrets/`, `openspec/` or `vendor/`, none of which have a lifecycle phase.
- Because a purpose rule is weaker to verify than a path rule, the requirement **enumerates the permitted OpenTofu root modules** (`tofu/` for the configuration phase, `bootstrap/` for the bootstrap phase) rather than leaving "is this bootstrap?" to judgement. Each phase has at most one root module, so `import`, `moved` and `backend` blocks — all root-only constructs — are declared once per phase.
- **BREAKING (spec)**: "OpenTofu lives under `tofu/`" stops asserting that _all_ OpenTofu root modules live under `tofu/`. It keeps governing the configuration-phase root module and its child modules, symlinks and provider caches.
- "Tool trees live at the repository root" is **deliberately left alone**. Its bootstrap clause still enumerates four artifacts and is already stale against the tree, but generalizing it is tidiness rather than necessity — the phase requirement makes that list non-normative — and `docs-site-multi-domain` already modifies the same requirement to add `docs/`. Two MODIFIED blocks against one requirement means whichever archives second silently discards the other's edits, so this change stays out of it.
- A bootstrap-phase directory holds whatever form of tooling fits its target — a script, a justfile, Nix, or OpenTofu where the target has a real API. The bootstrap root module is for **API-driven provisioning**, not for rewriting every bootstrap target in OpenTofu. `bootstrap/mikrotik/` stays an `.rsc` script and a justfile: first-boot authenticates as the factory admin before any API user exists, and expressing it in OpenTofu would mean leaning on `local-exec`/`remote-exec` provisioners, which OpenTofu itself documents as a last resort.
- No files move and nothing is provisioned. `bootstrap/cloudflare/` already exists as empty placeholders; populating it, the bootstrap root module, token minting and the vault split are all a later change.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `repo-layout`: adds the lifecycle-phase placement requirement and narrows "OpenTofu lives under `tofu/`" to the configuration-phase root module. No other requirement in the capability is touched.

## Impact

- **Behaviour**: none. No file moves, no build or flake change, no infrastructure touched. This is a contract change that makes an existing convention checkable and unblocks a bootstrap-phase root module.
- **Unblocks**: the bootstrap provisioning tier — `bootstrap/main.tofu` importing per-target child modules, provisioning the R2 state bucket and minting the scoped Cloudflare token that the `tofu/` root consumes.
  That change will carry the credential work and its own risks; this one only removes the layout prohibition.
- **Sequencing**: this change should land **before** `tofu-per-site-modules`, whose new `tofu-root-module` capability was written for the pre-phase world and asserts "every other OpenTofu source file SHALL live under `tofu/` inside a child module directory" — which forbids a bootstrap root module — and gives `cloudflare.tofu` ownership of "the state bucket", which is true today but contradicts moving R2 provisioning to `bootstrap/`. Landing this first gives that change the phase vocabulary to narrow both statements to the configuration phase; landing it second means archiving a prohibition this change then has to undo.
  The two capabilities are otherwise cleanly separable: this one governs _where_ root modules may exist, `tofu-root-module` governs _what is inside_ the configuration-phase one.
- **Documentation**: `bootstrap/AGENTS.md` keeps the prose and the hands-off table; the spec becomes the normative statement, so the two must not drift. The root `AGENTS.md` repo description gains nothing — it already lists the trees.
- **Not touched**: `tofu/AGENTS.md`, every existing tool tree, the `tofu-state` capability (state placement is already governed there, not by `repo-layout`), and the existing enumerations in the other three `repo-layout` requirements.
- **Known boundary case this exposes, deliberately left open**: `tofu/mikrotik/users.tofu` declares `routeros_system_user.terraform` while its own comment records that the password is rotated from `bootstrap/mikrotik/justfile`. Under the principle that credential is bootstrap-phase — it is what makes the relays configurable by tofu — so it arguably belongs under `bootstrap/`. Moving it risks locking tofu out of the relays, so it is named here and decided in the provisioning-tier change rather than silently settled by a layout rule.
