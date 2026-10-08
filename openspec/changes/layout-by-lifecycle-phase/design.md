## Context

See `proposal.md` — Why.

The facts that shape the approach:

- The rule already exists in prose. `bootstrap/AGENTS.md` opens with it and carries a **Hands off to** table (`nix/` → `deploy`/`nh`, `kubernetes/` → Flux, `mikrotik/` → OpenTofu, `talos/` → Flux in the guest), plus the converse — "nothing bootstrap-related lives under `modules/`, `mikrotik/`, or `src/`".
- `bootstrap/` already has its own `secretspec.toml`, separate from the root one. Phase separation of credentials is therefore already structural, not something this change invents.
- `bootstrap/cloudflare/` already exists, holding an empty `justfile` and an empty `main.tofu` — placeholders for the later change.
- `repo-layout`'s other three requirements (the `src/` occupant, Flux paths, tooling patterns) do not mention phases and are untouched.
- The `tofu-state` capability already governs where state lives, so `repo-layout` does not need to say anything about it beyond the pointer it already carries.

## Goals / Non-Goals

Goals:

- State the placement rule once, cross-cutting, so a new tool's home is derivable rather than argued.
- Remove the prohibition that blocks a bootstrap-phase OpenTofu root module.
- Keep the requirement verifiable despite being purpose-based.

Non-Goals:

- Moving any file, populating `bootstrap/cloudflare/`, or writing a line of OpenTofu.
- Minting credentials, splitting 1Password vaults, or touching the relay password. All of that is the provisioning-tier change.
- Classifying trees that do not act on infrastructure.
- Deciding whether `routeros_system_user.terraform` moves to `bootstrap/` — named in the proposal, settled later.

## Decisions

### Add a requirement rather than widening the OpenTofu one

The alternative was to fold the principle into "OpenTofu lives under `tofu/`", since that requirement is what currently blocks the bootstrap root module.
Rejected: the principle governs `modules/`, `kubernetes/`, `hubitat/` and `mikrotik/` too, and burying a cross-cutting rule inside an OpenTofu-specific requirement means it is discoverable only by someone already reading about OpenTofu.
A separate requirement states it once; the OpenTofu requirement then narrows to the configuration phase and defers.

### The tree follows the configuring tool, not the configured target

Stated loosely — "configuration lives in that tool's own tree" — the rule is ambiguous about whose tree "that tool" names, and the wrong reading licenses `kubernetes/main.tofu` or `modules/main.tofu`.
The rule is therefore written from the configuring side: the MikroTik relays and Authentik are both configured by OpenTofu, so both are declared under `tofu/`, and OpenTofu appears nowhere else but `tofu/` and `bootstrap/`.

This also settles what `mikrotik/` is. It holds topology diagrams and reference documents, not tooling, so it is outside the principle entirely rather than being a tool tree that happens to contain no tools.
The existing "Tool trees live at the repository root" requirement keeps naming it, which is the right place for it — that requirement is about where trees sit, not about lifecycle phase.

### Enumerate the root modules instead of trusting the purpose rule

A path rule ("is it under `tofu/`?") is mechanically checkable; a purpose rule ("is this bootstrap or configuration?") is arguable, and an arguable requirement gets re-litigated per tool, which is the thing this change exists to stop.
So the requirement names the permitted root modules explicitly — one per phase — and caps each phase at one.

The cap has an independent justification: `import`, `moved` and `backend` are root-only constructs in OpenTofu, so a second root module within a phase would mean declaring them twice.
That makes the cap enforceable by a property of the tool rather than by taste.

Alternative considered — enumerating every bootstrap target as well: rejected, because that is exactly the fixed list the old "Tool trees" requirement had, and adding a target would mean amending the spec. The phase rule plus the hands-off-to obligation is enough to place a target; only root modules need naming, because only they carry the ambiguity that matters.

### Generalize the bootstrap clause of "Tool trees live at the repository root"

It currently enumerates four artifacts (installer image and host install, MikroTik first-boot, cluster seed manifests, Talos machine-config base). That list is already incomplete relative to the tree, which also holds `secretspec.toml` and `cloudflare/`.
Replacing the list with a deferral to the phase requirement makes the two requirements agree by construction instead of by maintenance.

### Scope the principle explicitly

Stated without a scope, "tooling is placed by lifecycle phase" invites the question of which phase `docs/` or `vendor/` belongs to.
Naming the out-of-scope trees in the requirement costs one sentence and removes a whole category of argument.

## Risks / Trade-offs

- **A purpose rule can drift from the prose in `bootstrap/AGENTS.md`** → the spec becomes normative and the rule file keeps the narrative; the task list checks they agree rather than assuming it.
- **"Bootstrap or configuration?" will still be arguable at the margin** → the root-module enumeration bounds the damage: a wrong call about a justfile is cheap and reversible, a wrong call about a root module is caught by the cap.
- **The enumeration is a maintenance point** → it changes only when a phase gains or loses a root module, which should be close to never. Judged cheaper than an unverifiable requirement.
- **This change permits something it does not build** → the bootstrap root module is allowed the moment this lands and does not exist until the next change. A reader could find the permission and no implementation; the proposal's Impact says so explicitly.
- **`tofu-root-at-repo-root` holds a stale `repo-layout` delta** → it is being rewritten before it lands and will re-read the main spec. The risk is only that it archives on the stale delta first, which would revert this requirement's wording.

## Migration Plan

None — no behaviour changes and nothing to roll back. The change is the spec delta plus verification that the tree already satisfies it.

Rollback is reverting the commit; no infrastructure or build state is involved.

### A bootstrap directory is not obliged to be OpenTofu

The bootstrap root module is for API-driven provisioning, not a mandate to express every bootstrap target in OpenTofu.
`bootstrap/mikrotik/` stays an `.rsc` script and a justfile: first-boot authenticates as the factory admin before any API user exists, so expressing it in OpenTofu would mean `local-exec`/`remote-exec` provisioners, which OpenTofu documents as a last resort precisely because they put imperative, non-idempotent steps inside a declarative graph and record nothing useful in state.

The line falls naturally where the target gains an API: first-boot is imperative and stays a script; creating the `terraform` user and rotating its password is API work and could move into the bootstrap root module. Which side of that line the user resource ends up on is the provisioning-tier change's decision, not this one's.

## Open Questions

None. The one that stood here — whether `bootstrap/mikrotik/` should become OpenTofu — is answered above: it should not.
