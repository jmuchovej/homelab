## Why

`tofu/terraform.tfstate` is 2.8 MB of plaintext that exists only on this laptop, and its only history is four hand-made `.bak` snapshots sitting in the same directory on the same disk.
It records every RouterOS, Cloudflare, Authentik, and ZeroTier object in the homelab plus the sops-sourced credentials, Authentik tokens, and 1Password item values those resources carry, so losing the disk means reconstructing the entire control plane by import, and leaking the file means leaking the secrets.
An off-site copy is the goal; encryption is what makes an off-site copy acceptable.

## What Changes

- **BREAKING (workflow)**: OpenTofu state moves to a Cloudflare R2 bucket via the `s3` backend.
  Bare `tofu plan` / `tofu apply` stop working, because the backend credentials, the R2 endpoint, and the state-encryption passphrase all arrive as environment variables that only the `just` recipes inject.
- OpenTofu native state encryption is enabled at the same time, configured entirely through `TF_ENCRYPTION`, with `enforced = true` so a missing passphrase fails the run instead of silently writing plaintext.
  The object that lands in R2 is ciphertext on the very first write; plaintext state never leaves the machine.
- State locking uses the `s3` backend's `use_lockfile` (R2 implements the `If-Match` / `If-None-Match` conditional writes it needs), not DynamoDB.
- A new `tofu/justfile`, loaded as `mod tofu` from the root justfile, becomes the only entry point: `just tofu::plan` and `just tofu::apply`.
  They wrap `secretspec run` and keep the existing `-parallelism=1 -compact-warnings` defaults and pass-through arguments.
  `just` sets a module's working directory to the module's own directory, so the root module in `tofu/` is found without `cd` and without `-chdir`.
- A `just tofu::state-snapshot` recipe copies the live state object to a dated key under a `snapshots/` prefix after a successful apply.
  R2 implements neither `GetBucketVersioning` nor `PutBucketVersioning`, so a single key in R2 is one mutable object — strictly worse than the four `.bak` files it replaces.
  The copy is server-side (`rclone copyto` between two keys on the same remote) so the ciphertext moves without ever being decrypted.
- `secretspec.toml` already declares `TOFU_R2_ACCESS_KEY_ID`, `TOFU_R2_SECRET_ACCESS_KEY`, `TOFU_R2_ENDPOINT`, `TOFU_STATE_PASSPHRASE`, and `SOPS_AGE_KEY`, grouped as `[scopes.tofu]` and resolved through the `op` 1Password provider.
  The endpoint carries the Cloudflare account ID, which is why it is a declared secret rather than a literal in a tracked file.
  The recipes resolve that scope and nothing else, so secrets outside it are stripped from the environment OpenTofu's provider plugins run in.
- A `cloudflare_r2_bucket_lock` rule makes the snapshot prefix write-once: R2 bucket locks prevent both deletion and overwriting for a retention period, which protects the history from a fat-fingered script or a compromised R2 token in a way object versioning would not.
  The rule is scoped to `tofu/snapshots/` and must never reach the live state key or its lock object, which OpenTofu overwrites on every write.
- The bucket is created out-of-band and then imported as `cloudflare_r2_bucket`, with a `cloudflare_r2_bucket_lifecycle` rule expiring the `snapshots/` prefix.
  The R2 API token is **not** declared in OpenTofu: a credential that the backend needs in order to read the state cannot live inside that state.
- The existing local state file and its four backups are left in place untouched as the rollback path.

## Capabilities

### New Capabilities

- `tofu-state`: where OpenTofu state lives, how it is encrypted at rest, how concurrent runs are locked, how it is snapshotted, and how the credentials for all of that reach OpenTofu.

### Modified Capabilities

- `repo-layout`: the "OpenTofu lives under `tofu/`" requirement currently says "Local state and provider caches SHALL live alongside the root module in `tofu/`".
  State is no longer local, so that sentence narrows to provider caches, and its no-op-plan scenario stops asserting that no re-initialization is required (the backend change requires exactly that).

## Impact

- **Live infrastructure**: none.
  No resource changes state address, no provider is reconfigured, and no RouterOS, Cloudflare, Authentik, or ZeroTier object is touched.
  The acceptance gate is that the first `tofu plan` against R2 reports no changes.
  The only new resources are the imported bucket and its lifecycle rule.
- **State**: migrated once with `tofu init -migrate-state`.
  The local file is the rollback and stays on disk; nothing is deleted by this change.
- **Sequencing**: this change supersedes the premise of `tofu-root-at-repo-root`, which is in flight.
  That change's first goal is "no `cd`, no `-chdir`, no wrapper", and its D1 rejects a wrapper outright; a mandatory secretspec wrapper voids both.
  It also asserts `backend "local" { path = "tofu/terraform.tfstate" }` in its proposal, design, and task 2.1, and adds the same `just` recipes.
  The OpenTofu root therefore stays in `tofu/`, and that change is re-scoped to what never depended on the move: reflowing the per-datacenter modules so each site is described concisely rather than spread across many top-level files, retiring the 106 dead `import` blocks and 5 applied `moved` blocks, the new `tofu/kubernetes/` child module, and removing `ak.variables.tofu`.
  It therefore no longer modifies the `repo-layout` requirement this change modifies.
  Its one live hazard is already gone: the Cloudflare tunnel resources are tracked as `tofu/cf.idp-tunnel.tofu`.
- **Cloudflare API token**: the token behind `provider "cloudflare"` needs `Workers R2 Storage Write` added before the bucket can be read or imported.
  Scoping it is a dashboard action, not a code change.
- **Tooling**: `rclone` is already installed (`modules/programs/terminal/rclone.nix`) and is driven by an on-the-fly connection string, so no rclone remote is configured and no rclone config file holds a credential.
  `tofu/.terraform/` is re-initialized for the new backend; the provider cache is unaffected.
- **Docs**: `tofu/AGENTS.md`'s "**State is local** … There is no remote backend" bullet is replaced, and its Workflow section gains the secretspec requirement.
- **Not touched**: the `secrets/` tree and `.sops.yaml` (nothing new is encrypted with sops), every `*.tofu` resource definition, the `tofu/mikrotik.just` and `tofu/authentik.just` modules, and the key material that a later change may move off-site.
