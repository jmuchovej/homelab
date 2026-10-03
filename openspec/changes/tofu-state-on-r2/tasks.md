## 1. Out-of-band prerequisites

- [ ] 1.1 Add the `Workers R2 Storage Write` permission to the Cloudflare API token stored at `cloudflare.api-key` in `secrets/secrets.sops.yaml`, and verify with `tofu console` that `data.cloudflare_zone.domain.account.id` still resolves and the token is accepted (the existing plan must stay clean — a token edit that breaks DNS reads shows up here, before any state move).
- [x] 1.2 Provide the R2 bucket that holds state. **Done** — the bucket is `rbn`, pre-existing and shared with other content, so this change confines itself to the `tofu/` key prefix. Nothing was created.
- [x] 1.3 Provide an R2 API token scoped to that bucket, and record its access key ID, secret access key, and endpoint. **Done** — the credential authenticates. Note that it cannot list buckets (`rclone lsd r2:` returns empty, exit 0, because the token is bucket-scoped), so bucket reachability must be verified as `rclone lsf r2:rbn`, never by listing.
- [x] 1.4 Generate a high-entropy state passphrase and store it, the access key ID, the secret access key, and the endpoint in the 1Password `Homelab` vault; verify each is retrievable. **Done** — the `Cloudflare R2` item (fields `access-key-id`, `secret-access-key`, `endpoint`) and the `OpenTofu State` item (`password`).

## 2. Credential plumbing

- [x] 2.1 Declare the backend secrets in `secretspec.toml` and group them into a `[scopes.tofu]` subset; verify `secretspec check --explain --scope tofu --reason "<reason>"` reports every secret resolved and reveals no values. **Done** — `[scopes.tofu]` covers `SOPS_AGE_KEY`, `TOFU_R2_ACCESS_KEY_ID`, `TOFU_R2_SECRET_ACCESS_KEY`, `TOFU_R2_ENDPOINT`, `TOFU_STATE_PASSPHRASE`, each with an explicit `op` item/field `ref`, all `required`, all resolving.
- [x] 2.2 Create `tofu/justfile` with `init`, `plan`, `apply`, and `state-snapshot` recipes and add `mod tofu` to the root `justfile`; verify `just --list` shows the module and `just tofu::plan -help` runs OpenTofu's own help from `tofu/` as the working directory, with no `cd`, no `-chdir`, and no `[working-directory]` attribute anywhere. **Done** — `just tofu::_default` lists all five recipes, and `just tofu::plan -help` printed OpenTofu's plan help, proving `-`-prefixed args survive the nested `just` call.
- [ ] 2.3 Have the recipes wrap `secretspec run --scope tofu --reason "<per-recipe reason>"`, re-export `TOFU_R2_*` to `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_ENDPOINT_URL_S3`, assemble `TF_ENCRYPTION` from the passphrase, and pass `-parallelism=1 -compact-warnings` plus `*ARGS`; verify with `just tofu::plan -help` that the wrapper execs and that OpenTofu receives the appended argument.
- [x] 2.4 Verify the scope actually narrows the child environment: export a profile secret outside the `tofu` scope in the calling shell and confirm it is absent from the resolved environment while all five in-scope names are present. **Done** — `HUBITAT_URL=SENTINEL` exported in the parent was stripped; `SOPS_AGE_KEY`, `TOFU_R2_ACCESS_KEY_ID`, `TOFU_R2_SECRET_ACCESS_KEY`, `TOFU_R2_ENDPOINT`, `TOFU_STATE_PASSPHRASE` all present.
- [x] 2.5 Confirm no credential is echoed: verify neither the passphrase nor either R2 key appears in recipe output, and that the recipe bodies do not `echo` the assembled `TF_ENCRYPTION`. **Done** — each value grepped for by content against the recipe's own output; all absent. The `[script]` bodies reference `${TOFU_STATE_PASSPHRASE}` by name, so even just's line echoing cannot print it.
- [x] 2.6 Resolve the `TOFU_R2_ENDPOINT` shape: the stored value ends in `/rbn`, but both the `s3` backend (with `bucket` + `use_path_style`) and rclone (with `r2:<bucket>/…`) append the bucket themselves, so a bucket-qualified endpoint yields `…/rbn/rbn/…`. Store the bare account host instead; verify `rclone lsf r2:rbn` succeeds and that the endpoint no longer contains a path segment. **Done** — endpoint is now the bare account host and `rclone lsf r2:rbn` succeeds, returning zero entries (the bucket is empty).

## 3. Pre-migration safety

- [ ] 3.1 Take a dated plaintext snapshot of the current state (`cp tofu/terraform.tfstate tofu/terraform.tfstate.$(date -u +%Y%m%d-%H%M%S).backup`) and verify it parses as JSON with a non-zero `.serial` and the same `.lineage` as the live file.
- [ ] 3.2 Record the current baseline: run the existing plan and verify it reports no changes, so that any post-migration diff is attributable to the migration rather than to pre-existing drift. If it is not clean, stop and resolve the drift before proceeding.

## 4. Backend and encryption

- [ ] 4.1 Add the `backend "s3"` block to `tofu/main.tofu` per design.md (bucket, key, `region = "auto"`, `use_path_style`, the four `skip_*` AWS-isms, `skip_s3_checksum`, `use_lockfile`), with no endpoint and no credentials; verify `nix fmt` leaves it unchanged and `rg -n 'r2.cloudflarestorage' --glob '!.terraform/**'` returns no tracked match.
- [ ] 4.2 Migrate with the fallback path: `TOFU_STATE_FALLBACK=1 just tofu::init -migrate-state`, answering yes to the copy prompt; verify it completes and that `tofu/terraform.tfstate` on disk is byte-identical to the 3.1 snapshot (the local file must not have been rewritten).
- [ ] 4.3 Download the live object with `rclone cat` and verify it is an encryption envelope — it has top-level encryption metadata, no `"resources"` key, and a grep for a known credential value from the local state finds nothing. The fallback applies to reads only, so this must already be ciphertext.
- [ ] 4.4 Verify the steady-state config takes over: run `just tofu::plan` with `TOFU_STATE_FALLBACK` unset and confirm it reads the encrypted state successfully, proving `enforced = true` is in force and the plaintext-reading path is no longer needed.
- [ ] 4.5 **Acceptance gate**: that same `just tofu::plan` must report no changes. If anything is proposed, stop and roll back per design.md rather than applying.
- [ ] 4.6 Verify fail-closed behavior: run bare `tofu plan` from inside `tofu/` with no secretspec environment and verify it fails with a backend or encryption error and does not create or read a local state file; then unset only `TOFU_STATE_PASSPHRASE` within the recipe's environment and verify the failure is specifically an encryption error.
- [ ] 4.7 Verify the fallback cannot be entered by accident: confirm that with `TOFU_STATE_FALLBACK` unset the assembled `TF_ENCRYPTION` contains no `unencrypted` method and no `fallback` block, and that it does contain `enforced = true`.

## 5. Locking

- [ ] 5.1 Verify a lock is taken and released: start `just tofu::apply -refresh-only` (or any state-mutating operation), confirm `tofu/terraform.tfstate.tflock` appears in the bucket while it runs, and that it no longer blocks a subsequent operation afterward.
- [ ] 5.2 Verify contention is refused: hold the lock and start a second apply, and confirm it exits with a state-lock error naming the holder rather than writing state.
- [ ] 5.3 If either verification fails on a checksum error (opentofu#2605), remove `use_lockfile`, re-run `init`, record the deferral in the change notes, and confirm 4.5 still reports no changes. Do not work around it by disabling `skip_s3_checksum`.

## 6. Snapshots

- [ ] 6.1 Add the `state-snapshot` recipe to `tofu/justfile`, server-side copying the live key to `tofu/snapshots/<utc-timestamp>.tfstate` with `rclone copyto` using an on-the-fly connection string; verify a run creates the object and that `rclone check` reports it identical to the live object.
- [ ] 6.2 Verify the snapshot is ciphertext and was never decrypted: confirm the new object is an encryption envelope and that the recipe contains no `tofu state pull`.
- [ ] 6.3 Chain the snapshot onto the end of `tofu::apply` so a successful apply always leaves one behind, and verify a full `just tofu::apply` run produces exactly one new snapshot object.
- [ ] 6.4 Verify restore works end to end: copy a snapshot back over a scratch key, point a throwaway backend `key` at it, and confirm `tofu plan` reads it successfully. Do not overwrite the live key during this test.

## 7. Declare the bucket

- [ ] 7.0 Enumerate `rbn`'s existing lifecycle and lock configuration before declaring anything, since both provider resources hold the bucket's complete rule list and will delete rules they do not declare; verify the enumeration against the dashboard, and if any rule exists for a prefix outside `tofu/`, stop and confirm how it should be carried rather than assuming it can be dropped.
- [ ] 7.1 Add `cloudflare_r2_bucket.rbn` with `account_id = data.cloudflare_zone.domain.account.id`, `lifecycle { prevent_destroy = true }`, and an `import` block targeting `<account_id>/rbn/default`; verify `just tofu::plan` shows the import with no attribute changes.
- [ ] 7.2 Add `cloudflare_r2_bucket_lifecycle` carrying every rule found in 7.0 plus one enabled rule scoped to prefix `tofu/snapshots/` with `delete_objects_transition` at `max_age = 31536000` (`type = "Age"`, seconds — confirmed against the R2 lifecycle API reference, which documents `maxAge` in seconds); verify the plan creates exactly that one resource and that its rule list is a superset of what 7.0 found.
- [ ] 7.3 Add `cloudflare_r2_bucket_lock` carrying every rule found in 7.0 plus one enabled rule scoped to prefix `tofu/snapshots/` with `condition = { type = "Age", max_age_seconds = 7776000 }` (90 days); before applying, verify in the plan output that every rule carries a non-empty `prefix`, that no prefix matches `tofu/terraform.tfstate` or `tofu/terraform.tfstate.tflock` or any non-`tofu/` key this change does not own, and that `max_age_seconds` is strictly less than the lifecycle `max_age` from 7.2.
- [ ] 7.4 Apply 7.1 through 7.3 via `just tofu::apply`, then verify the bucket's lifecycle and lock configuration in the dashboard match what was planned, and that `just tofu::plan` is clean afterward.
- [ ] 7.5 Verify the lock does not reach the live state: run `just tofu::apply -refresh-only` after the lock is in force and confirm the state write succeeds; then attempt to delete a snapshot object with the same R2 credential and confirm the object store refuses it.

## 8. Documentation and sequencing

- [ ] 8.1 Replace the "**State is local** … There is no remote backend" bullet in `tofu/AGENTS.md` with the R2 backend, encryption, locking, and snapshot facts, add the two bucket-lock constraints (never over the live key or its lock object; retention shorter than the lifecycle expiry) since a naive edit to either rule is silently destructive, and rewrite its Workflow section for `just tofu::plan` / `tofu::apply` and why bare `tofu` no longer works; verify the file keeps one sentence per line and that no other rule restates these facts.
- [ ] 8.2 Hand off to the re-scoped successor of `tofu-root-at-repo-root` (reflowing the per-datacenter modules, with the root staying in `tofu/`): verify no in-flight change still asserts `backend "local"` or claims the `repo-layout` requirement this change owns (`rg -n 'backend "local"' openspec/changes/`), and that `openspec validate --strict` passes for every active change.
- [ ] 8.3 Correct the `just tofu-plan` / `just tofu-apply` references in the root `CLAUDE.md`/`AGENTS.md` Essential commands section to `just tofu::plan` / `just tofu::apply`, and verify `just --list` output matches what is documented.
- [ ] 8.4 Run `openspec validate tofu-state-on-r2 --strict` and `nix fmt`, and verify both are clean before committing.
- [ ] 8.5 Commit once per task group as that group completes, by explicit paths, after verifying every hunk in each shared file is this change's and that `jj file track` has picked up any new file (`tofu/justfile`); leave `tofu/terraform.tfstate*` untracked and in place. Verify at the end that no file this change touched is left uncommitted.
