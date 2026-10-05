## Context

See `proposal.md` — Why.

The constraints that shape every decision below:

- **Backend configuration is evaluated before anything else.**
  There is no provider, no variable, and no data source at that point, so `data.sops_file.secrets` — the single source of truth for every other OpenTofu credential in this repo — cannot supply the backend.
  Anything the backend needs must come from the process environment or a `-backend-config` file.
- **The `encryption` block has the same limitation.**
  It is parsed outside the normal evaluation graph and cannot reference variables, locals, or data sources.
- **R2 is S3-compatible, not S3.**
  It implements `If-Match` / `If-None-Match` conditional writes on `PutObject` (so native locking works) but not `GetBucketVersioning` / `PutBucketVersioning` (so there is no version history), and it supports `FULL_OBJECT` checksums only for CRC-64/NVME, while the AWS SDK sends CRC-32 by default.
- **The state is a liability, not just an asset.**
  2.8 MB containing sops-sourced credentials, Authentik tokens, and 1Password item values.
- **The state is also already known to lie.**
  `tofu/AGENTS.md` records that a failed RouterOS update still lands the _planned_ value in state, so the next plan is clean while reality has drifted.
  Bad writes, not dead disks, are the most likely thing to need recovering from.
- **OpenTofu 1.12.6** is in use, so `use_lockfile` (1.10+) and native state encryption (1.7+) are both available.
- **secretspec** resolves through the `1password` provider under the `development` profile, and the project policy requires an access reason on every resolution.
  `secretspec.toml` already declares `[scopes.tofu]` over five secrets — `SOPS_AGE_KEY`, `TOFU_R2_ACCESS_KEY_ID`, `TOFU_R2_SECRET_ACCESS_KEY`, `TOFU_R2_ENDPOINT`, `TOFU_STATE_PASSPHRASE` — each with an explicit 1Password item/field `ref` through the `op` provider alias, all `required` (the default) and all resolving.
  Both `check` and `run` take `-S/--scope`, and on `run` the excluded secrets are _removed_ from the child environment even when inherited.

## Goals / Non-Goals

Goals:

- One authoritative state object, off-site, encrypted, locked, with retained history.
- Zero change to any live resource; the migration is provably a no-op.
- A rollback that does not depend on R2 being reachable or on the passphrase being correct.

Non-Goals:

- Moving the OpenTofu root module. It stays in `tofu/`; see the sequencing note in `proposal.md` — Impact for why `tofu-root-at-repo-root` is re-scoped rather than carried.
- Off-siting the gitignored age/SSH key material under `secrets/keys/`, which is the other unrecoverable thing in this repo and deserves its own change.
- Multi-workspace state, remote execution, or CI-driven apply.
- Defending against loss of the Cloudflare account; this is disk-loss and machine-loss insurance by explicit decision.

## Decisions

### Backend split: structure in code, secrets and endpoint in the environment

```hcl
terraform {
  backend "s3" {
    bucket = "rbn"
    key    = "tofu/terraform.tfstate"
    region = "auto"

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}
```

The endpoint is **not** in this block.
It is `https://<account-id>.r2.cloudflarestorage.com`, and the repo already treats the Cloudflare account identifier as non-public (the apex domain itself lives in sops), so it arrives as `AWS_ENDPOINT_URL_S3` alongside the credentials.

Alternatives rejected:

- **`endpoints = { s3 = ... }` in the block**: publishes the account ID in a tracked file for no gain.
- **`-backend-config` with the access key**: `init` caches the resolved backend configuration into `tofu/.terraform/terraform.tfstate`, so the credential would be written to disk in plaintext. Gitignored is not the same as absent.
- **An AWS shared-credentials profile** (which the backend docs recommend): a second credential store on disk, outside secretspec, holding a secret that is not an AWS one.

`skip_s3_checksum` is required rather than optional: the AWS SDK's default integrity behavior sends a full-object CRC-32, which R2 rejects for anything but CRC-64/NVME.

### Encryption entirely in `TF_ENCRYPTION`

Steady state, assembled by the recipes from the secretspec passphrase (HCL blocks take no commas):

```hcl
key_provider "pbkdf2" "state" { passphrase = "<from secretspec>" }
method "aes_gcm" "state" { keys = key_provider.pbkdf2.state }
state {
  method   = method.aes_gcm.state
  enforced = true
}
```

`enforced = true` is the whole point: without it, OpenTofu will happily read and write unencrypted state when no method resolves, which converts a forgotten passphrase from a loud failure into a silent plaintext upload.

**But `enforced = true` cannot be set during the migration itself.** OpenTofu refuses to read plaintext state once encryption is configured — on the grounds that unencrypted data could have been tampered with — and the local state this change migrates _is_ plaintext. Reading it requires naming an `unencrypted` method and reaching it through a `fallback`, which `enforced` forbids. So the one migrating run uses:

```hcl
key_provider "pbkdf2" "state" { passphrase = "<from secretspec>" }
method "aes_gcm" "state" { keys = key_provider.pbkdf2.state }
method "unencrypted" "migrate" {}
state {
  method = method.aes_gcm.state
  fallback { method = method.unencrypted.migrate }
}
```

Fallback applies to reads only — saves always use the new method — so this still writes ciphertext to R2 on the first write. The recipes build this variant only when `TOFU_STATE_FALLBACK` is set in the environment, and the steady-state variant otherwise, so the plaintext-reading path is opt-in per invocation and cannot be entered by accident. It is also the path for re-encrypting under a rotated passphrase later, which is why it stays in the recipe rather than being a one-shot.

The environment carries the complete block rather than only the passphrase.
OpenTofu does merge `TF_ENCRYPTION` over an in-code `encryption` block, which would allow declaring `method` and `state` in `main.tofu` and overriding only the `key_provider` — but a half-declared `key_provider` with no passphrase is not valid on its own, so the in-code half would break any tooling that parses the configuration without the environment (`tofu-ls`, `tofu validate`, `treefmt`'s terraform formatter is fine, but validation is not).
All-in-environment keeps the tracked configuration self-consistent.

`pbkdf2` over the `aws_kms` / `gcp_kms` / `openbao` key providers because there is no KMS in play and OpenBao is still a design (see `openspec/`-adjacent notes and `modules/services/openbao.nix`, which is not deployed).
When OpenBao lands, switching the key provider is a re-encrypt, not a redesign — worth a `key_provider "openbao"` note in the follow-up ledger rather than a blocker here.

### Migrate with encryption already configured

Order matters and there is exactly one safe order: configure the backend **and** encryption together, then `tofu init -migrate-state`.
The migration write goes through the encryption method, so the first object ever created in R2 is ciphertext.

**The local state file does not survive the migration.** OpenTofu zeroes `tofu/terraform.tfstate` to nothing once the remote backend holds the state, so it cannot be used by accident; the pre-migration content is written to `tofu/terraform.tfstate.backup` as compact JSON. Both that and the explicit dated snapshot taken beforehand are plaintext on an encrypted-disk laptop, and they — not the live local file — are the rollback. Taking the snapshot is therefore load-bearing rather than belt-and-braces: without it the only plaintext copy would be a file OpenTofu overwrites on the next backend change.

Alternative rejected — **encrypt locally first, then migrate**: appealing in that it proves encryption works before involving R2, but forcing a local state rewrite needs a state-writing operation, and the only ones available either refresh every resource (hundreds of flaky RouterOS REST calls, and the AGENTS.md warning about partial failures applies) or push state with a hand-managed serial. Not worth it when the single-step order already guarantees no plaintext reaches R2.

### Snapshots are server-side object copies, never `state pull`

`tofu state pull` emits **decrypted** state.
A snapshot built by pulling and re-uploading would write the plaintext secrets into the same bucket as the ciphertext, which is a worse outcome than having no snapshots at all.
`rclone copyto` between two keys on the same remote performs a server-side copy: the ciphertext is duplicated without transiting the machine and without the passphrase being involved.

rclone is driven by an on-the-fly connection string built from the same environment variables (`:s3,provider=Cloudflare,access_key_id=…,secret_access_key=…,endpoint=…:`), so no rclone remote is configured and no rclone config file holds a credential.

Key layout in the bucket:

| Key                                      | What it is                             |
| ---------------------------------------- | -------------------------------------- |
| `tofu/terraform.tfstate`                 | live state, the backend's `key`        |
| `tofu/terraform.tfstate.tflock`          | lock object, managed by `use_lockfile` |
| `tofu/snapshots/<utc-timestamp>.tfstate` | post-apply copies, lifecycle-expired   |

The lifecycle rule is scoped to the `tofu/snapshots/` prefix so it can never reach the live object or the lock.

### The bucket is declared; the credential is not

`cloudflare_r2_bucket` is imported (`<account_id>/<bucket_name>/<jurisdiction>`) with `prevent_destroy`, and `cloudflare_r2_bucket_lifecycle` declares the expiry rule.
Declaring the bucket that holds the state is circular on paper but harmless in practice: the bucket must already exist for `init` to succeed, so OpenTofu only ever reconciles it.
`prevent_destroy` makes the circularity non-load-bearing — a `tofu destroy` cannot take out the state's own home.

The **R2 API token is deliberately not declared.** Its access key is what the backend needs in order to read the state, so putting it under OpenTofu management would mean the credential required to open the state lives inside that state, and any rotation would lock the operator out between plan and apply. It is created by hand and stored in 1Password.

Note that `cloudflare_r2_bucket_lifecycle` does not support `terraform import`, so the lifecycle rule is created by OpenTofu rather than imported — it is the one resource this change actually creates.

### `rbn` is a shared bucket, which constrains all three

The bucket is `rbn` — the repo's namespace, a general-purpose bucket rather than a state-dedicated one — and the R2 token is scoped to it.
It is currently empty, so nothing collides today; what follows is about keeping that true.
Two consequences follow, and neither is cosmetic:

- **Every key this change writes stays under the `tofu/` prefix.** That was tidiness when the bucket was imagined as state-only; in a shared bucket it is what keeps state from colliding with whatever else lives there. `tofu/terraform.tfstate`, `tofu/terraform.tfstate.tflock`, `tofu/snapshots/`.
- **`cloudflare_r2_bucket_lifecycle` and `cloudflare_r2_bucket_lock` are whole-bucket resources**, each holding the bucket's _complete_ `rules` list — the provider PUTs the entire configuration. Declaring either one with only this change's rule therefore **deletes every other lifecycle or lock rule on `rbn`**, whoever set it. Any pre-existing rules must be enumerated first and carried in the same resource, which makes OpenTofu the sole owner of `rbn`'s lifecycle and lock configuration from then on.

The alternative — a dedicated state bucket, leaving `rbn` entirely alone — trades a second bucket and a second token scope for unambiguous ownership. It is the cleaner shape on paper and is worth revisiting if `rbn` turns out to carry rules from other tooling.

### A `tofu/justfile` module is the only entry point

`secretspec run --scope tofu --reason "<what this run is for>"` wraps every recipe; the recipes re-export `TOFU_R2_*` to the `AWS_*` names the backend expects and assemble `TF_ENCRYPTION`.
This is also where the plan and apply recipes that `AGENTS.md` has documented all along finally exist.

`--scope tofu` is doing two jobs, and the second is the one worth being deliberate about.
It selects the five secrets OpenTofu needs, and it _strips everything else_ from the child environment even when the parent shell exported it — so an OpenTofu run, with its ~30 providers and their plugin processes, cannot see `HUBITAT_PASSWORD` or any secret added to the profile later.
Resolving the whole profile would have handed every provider plugin every secret in the project for no reason.
`SOPS_AGE_KEY` is in the scope, so the `carlpett/sops` provider's key arrives through the same wrapper rather than being an ambient precondition of the shell — one entry point supplies state access and secret decryption both, and neither works outside it.

The recipes live in `tofu/justfile`, loaded from the root justfile as a bare `mod tofu` — `just` resolves a module named `tofu` to `tofu/justfile` on its own, and sets the module's working directory to `tofu/`, which is exactly where the root module is.
The root module therefore needs neither `cd` nor `-chdir` nor a `[working-directory]` attribute: the correct working directory is a property of where the recipes live.

Alternatives rejected:

- **`tofu-plan` / `tofu-apply` recipes in the root justfile with `[working-directory("tofu/")]`**: works, but hardcodes the root module's location in the root justfile and puts OpenTofu recipes at a different nesting level from `mikrotik` and `authentik`, which are already modules.
- **A `tofu/tofu.just` file**: `mikrotik.just` and `authentik.just` use that form, but they need an explicit path in the `mod` line. A `justfile` inside the directory is resolved implicitly, and the module is named for the directory it operates in.

Noticed, not changed: `tofu/mikrotik.just` and `tofu/authentik.just` remain siblings of the new module (`just mikrotik::…`, not `just tofu::mikrotik::…`). Nesting them under it would rename every recipe path users and docs refer to, which is not this change's job.

### Snapshot immutability via a prefix-scoped bucket lock

R2 bucket locks prevent deletion **and** overwriting for a retention period and take precedence over lifecycle rules.
Applied to `tofu/snapshots/` this is a better fit than the object versioning R2 lacks: versioning protects history from being overwritten, while a lock also protects it from being deleted by the very credential the backend already holds. Snapshot keys are unique timestamps that are never rewritten, so the lock costs nothing operationally.

```hcl
resource "cloudflare_r2_bucket_lock" "tofu-state" {
  account_id  = data.cloudflare_zone.domain.account.id
  bucket_name = cloudflare_r2_bucket.tofu-state.name
  rules = [{
    id        = "retain-state-snapshots"
    enabled   = true
    prefix    = "tofu/snapshots/"
    condition = { type = "Age", max_age_seconds = 7776000 } # 90d
  }]
}
```

Two constraints, both of which turn a working setup into a broken one if violated:

1. **The rule's prefix must never cover the live state key or its lock object.** OpenTofu overwrites `tofu/terraform.tfstate` on every state write and churns `tofu/terraform.tfstate.tflock` on every operation, so a lock reaching either — most easily via an empty prefix, which scopes to the whole bucket — bricks every apply. This is why the live key sits at `tofu/terraform.tfstate` rather than inside `tofu/snapshots/`: the nesting is load-bearing, not cosmetic.
2. **Retention must be shorter than the lifecycle expiry.** Locks win over lifecycle, so an `Indefinite` lock (or any retention longer than 365 days) under a 365-day delete rule means the delete never fires and the prefix grows without bound. 90-day lock under 365-day expiry is coherent: a snapshot is immutable for 90 days, then merely present, then expired.

Like `cloudflare_r2_bucket_lifecycle`, this resource does not support `terraform import`, so it is created by OpenTofu rather than imported.

## Risks / Trade-offs

- **Lock object may trip the checksum setting** → [opentofu#2605](https://github.com/opentofu/opentofu/issues/2605) reports the lock write not honoring `skip_s3_checksum`. Verified explicitly as its own task; if it fails, `use_lockfile` is dropped and locking is deferred, which costs little for a single operator. This does not block the rest of the change.
- **Passphrase loss is state loss** → the plaintext local state file and its four backups stay on disk indefinitely, and the passphrase lives in 1Password, which is itself backed up. Do not delete the local files as part of this change.
- **A bad write now overwrites the only authoritative copy** → snapshots exist precisely for this; the `tofu::apply` recipe takes one on success so it cannot be forgotten.
- **No network, no OpenTofu** → accepted: the address spaces in play do not overlap a tethered hotspot, so a laptop can reach both R2 and the management plane during an outage.
- **`init -migrate-state` on a 2.8 MB state over a flaky link** → it is a single `PutObject`; the local file is untouched on failure and the operation is idempotent on retry.
- **R2's conditional-write and checksum behavior could regress** → the failure mode is a loud backend error, not a corrupt state, and the local rollback copy remains.
- **A bucket lock applied too widely bricks every apply** → the prefix is asserted against the live key and the lock key before the rule is created, and the rule is never written without a prefix. The failure is loud and recoverable only after the retention period, which is why it is verified rather than assumed.
- **The in-flight `tofu-root-at-repo-root` change rests on a premise this one removes** → it is re-scoped to reflowing the per-datacenter modules so a site is described concisely instead of across many top-level files in `tofu/`. Its one live hazard — the untracked Cloudflare tunnel file declaring four resources that exist in state — is already resolved: it is tracked as `tofu/cf.idp-tunnel.tofu`, so a plan from a clean checkout no longer proposes destroying them.

## Migration Plan

1. Add `Workers R2 Storage Write` to the Cloudflare API token behind `provider "cloudflare"`.
2. Create the bucket and a scoped R2 API token out-of-band; store the access key, secret, endpoint, and a generated passphrase in 1Password; declare them in `secretspec.toml`; confirm with `secretspec check --explain`.
3. Snapshot the current local state by hand (dated copy next to the existing `.bak` files) before touching any configuration.
4. Add `tofu/justfile` with `init`, `plan`, `apply`, and `state-snapshot`, and `mod tofu` to the root justfile; add the backend block; `just tofu::init -migrate-state`.
5. Download the new R2 object and confirm it is an encryption envelope, not JSON with a `resources` key.
6. `just tofu::plan` → must report **no changes**. This is the acceptance gate.
7. Verify locking, verify the snapshot recipe, then import the bucket and create the lifecycle and bucket-lock rules.
8. Update `tofu/AGENTS.md`, and re-scope `tofu-root-at-repo-root`.

Rollback at any point before step 8: remove the backend block and the `encryption` configuration, run `tofu init -migrate-state` back to local (or simply `tofu init` — the untouched local file is still authoritative and current), and delete the R2 object.
Nothing in the live infrastructure has to be reverted because nothing in it changed.

## Open Questions

- Snapshot retention: 365 days is the starting value. At ~3 MB per apply this is negligible either way, so it can be tuned later without touching the specs.
- Whether a periodic snapshot (not only post-apply) is worth adding. Deferred until there is evidence that applies are infrequent enough for the gap to matter.
