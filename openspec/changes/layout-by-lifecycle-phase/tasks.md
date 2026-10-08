## 1. Verify the tree already satisfies the rule

- [ ] 1.1 Confirm every directory under `bootstrap/` is bootstrap-phase and names what it hands off to: check `nix/`, `kubernetes/`, `mikrotik/`, `talos/` and `cloudflare/` against the **Hands off to** table in `bootstrap/AGENTS.md`, and verify `cloudflare/` is listed there too — it exists as empty placeholders but predates the table, so if it is absent the table is already stale.
- [ ] 1.2 Confirm no configuration-phase tooling sits under `bootstrap/`, and that the converse claim in `bootstrap/AGENTS.md` ("nothing bootstrap-related lives under `modules/`, `mikrotik/`, or `src/`") still holds; verify by listing each `bootstrap/` subdirectory's contents rather than trusting the prose.
- [ ] 1.3 Confirm the root-module count: exactly one configuration-phase root module (`tofu/`) and at most one bootstrap-phase root module. Verify with `rg -l '^(import|moved) \{|backend "' --glob '*.tofu'` that root-only constructs appear in no directory other than those, remembering that `bootstrap/cloudflare/main.tofu` is currently empty so the bootstrap root does not yet exist.
- [ ] 1.5 Confirm no OpenTofu lives outside `tofu/` and `bootstrap/`: `rg -l --glob '*.tofu' . | rg -v '^(\./)?(tofu|bootstrap)/'` must return nothing. This is the check that enforces "the tree follows the configuring tool" — in particular that `mikrotik/` holds only diagrams and reference documents, with the relays' configuration declared under `tofu/`. If this fails on leftover scaffolding rather than real configuration, resolve it with the repo owner rather than treating it as a rule violation to design around.
- [ ] 1.4 Confirm the out-of-scope list in the new requirement matches the tree: verify every top-level directory is either a tool tree named by `repo-layout`, listed as out-of-scope, or covered by another requirement — so the requirement leaves nothing unclassified.

## 2. Write the delta

- [ ] 2.1 Add the `Infra-acting tooling is placed by lifecycle phase` requirement with its four scenarios; verify it states the hands-off-to obligation, the converse prohibition, the explicit out-of-scope list, and the one-root-module-per-phase cap with its root-only-constructs justification.
- [ ] 2.2 Verify `Tool trees live at the repository root` is **not** modified by this change: `docs-site-multi-domain` already modifies it to add `docs/`, and two MODIFIED blocks against one requirement means whichever archives second discards the other's edits. Confirm this change's delta contains no block for it.
- [ ] 2.3 Restate `OpenTofu lives under `tofu/`` in full, narrowed to the configuration-phase root module and explicitly permitting a bootstrap-phase root module elsewhere; verify both its scenarios are carried and that the `tofu-state` pointer added by the previous change survives.
- [ ] 2.4 Verify the delta against the live main spec: every MODIFIED header matches the existing requirement text exactly (whitespace-insensitive), or archive will fail to match it and will append a duplicate requirement instead of replacing one.

## 3. Reconcile the documentation

- [ ] 3.1 Reconcile `bootstrap/AGENTS.md` with the spec: it already carries the principle in prose, so verify the two do not contradict, add `cloudflare/` to the hands-off table if 1.1 found it missing, and do not duplicate the normative wording — the rule file keeps the narrative and the table, the spec is normative.
- [ ] 3.2 Verify no other directory `AGENTS.md` restates OpenTofu root-module placement in a way the narrowed requirement now contradicts (`rg -l 'root module' .agents/rules/`), and that `tofu/AGENTS.md`'s "Single root module" line is still true of the configuration phase.

## 4. Close out

- [ ] 4.1 Run `openspec validate layout-by-lifecycle-phase --strict` and confirm it passes.
- [ ] 4.2 Verify this change is the only active one claiming the `repo-layout` requirements it touches: `rg -l 'Requirement: OpenTofu lives under' openspec/changes/*/specs/repo-layout/spec.md` must name only this change. `docs-site-multi-domain` claims `Tool trees live at the repository root`, which this change no longer touches, so that is not a collision.
- [ ] 4.3 Record the `tofu-per-site-modules` conflict for its owner rather than editing it: its `tofu-root-module` capability forbids OpenTofu outside `tofu/` and assigns the state bucket to `cloudflare.tofu`. Both need narrowing to the configuration phase once this change lands; verify the note reaches that change's artifacts or the owner directly.
- [ ] 4.4 Run `treefmt` over the touched paths only, not repo-wide, since the working copy carries unrelated concurrent work.
- [ ] 4.5 Commit by explicit paths after verifying every hunk in each shared file belongs to this change; `bootstrap/AGENTS.md` and the root `AGENTS.md` are both files the repo owner edits concurrently.
