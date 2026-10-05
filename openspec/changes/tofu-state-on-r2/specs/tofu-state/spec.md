## Purpose

Defines where OpenTofu state for the homelab lives, how it is protected at rest and against concurrent writes, how its history is retained, and how the credentials for all of that reach OpenTofu — so that losing a workstation does not mean reconstructing the control plane by import.

## ADDED Requirements

### Requirement: State lives in an off-site object store

OpenTofu state SHALL be stored in a Cloudflare R2 bucket through the `s3` backend, keyed at a single fixed object path, and SHALL NOT be the authoritative copy on any workstation filesystem.
The backend SHALL address R2 through a path-style endpoint with AWS-specific credential, region, account, and checksum validation disabled, because R2 implements neither STS, EC2 instance metadata, AWS region names, nor full-object checksums for any algorithm other than CRC-64/NVME.

#### Scenario: Plan is a no-op immediately after migration

- **WHEN** `tofu plan` is run against the R2 backend directly after the state is migrated
- **THEN** it reports no changes, and every resource keeps the state address it had under the local backend

#### Scenario: State survives loss of the workstation

- **WHEN** a workstation with no prior OpenTofu state on disk is given the backend credentials and runs `tofu init` followed by `tofu plan`
- **THEN** the state is read from R2 and the plan reports no changes, with no state file copied by hand

#### Scenario: The Cloudflare account identifier is not published

- **WHEN** the tracked OpenTofu configuration is searched for the R2 endpoint host
- **THEN** there are no matches, because the endpoint reaches OpenTofu through the environment rather than a tracked file

### Requirement: State is encrypted before it leaves the machine

State SHALL be encrypted with OpenTofu native state encryption, and encryption SHALL be enforced such that a run with no usable key fails rather than reading or writing unencrypted state.
Plaintext state SHALL NOT be written to the object store at any point, including the initial migration.

#### Scenario: The stored object is ciphertext

- **WHEN** the live state object is downloaded from R2 and inspected
- **THEN** it is an encryption envelope, and it contains neither resource addresses nor any secret value that the state carries

#### Scenario: A run without the key fails closed

- **WHEN** an operation is attempted with the encryption key absent from the environment
- **THEN** it fails before reaching the object store, and the state object is left unmodified

#### Scenario: A run with the wrong key fails closed

- **WHEN** an operation is attempted with an encryption key that does not match the stored state
- **THEN** it fails with a decryption error rather than reading the state or writing an unencrypted replacement, and the state object is left unmodified

#### Scenario: Secrets in state are not readable from the bucket

- **WHEN** a credential that OpenTofu records in state is searched for in the downloaded state object
- **THEN** it does not appear in plaintext

### Requirement: Concurrent runs are locked

The backend SHALL take a lock for every state-mutating operation using the object store's conditional-write support, without any separate locking service.
A second concurrent operation SHALL fail to acquire the lock rather than proceed.

#### Scenario: A second apply is refused

- **WHEN** an apply holds the lock and a second `tofu apply` is started against the same state
- **THEN** the second invocation fails with a state-lock error naming the holder, and does not write state

#### Scenario: The lock is released on completion

- **WHEN** an operation finishes, whether it succeeded or failed
- **THEN** the lock object no longer blocks the next operation

### Requirement: State history is retained outside the live object

Because the object store provides no object versioning, a dated copy of the live state object SHALL be retainable under a dedicated prefix, and that copy SHALL be made without decrypting the state.
Copies under that prefix SHALL be protected against deletion and overwriting for a bounded retention period, and SHALL expire automatically after a longer bounded age.
The retention protection SHALL NOT extend to the live state object or its lock object, which are overwritten on every state write.

#### Scenario: A snapshot is taken after an apply

- **WHEN** a snapshot is requested after a successful apply
- **THEN** a new object exists under the snapshot prefix, keyed by UTC timestamp, byte-identical to the live state object at that moment

#### Scenario: Snapshots stay encrypted

- **WHEN** a snapshot object is downloaded and inspected
- **THEN** it is an encryption envelope, identical in form to the live object, and no plaintext copy was produced in order to create it

#### Scenario: Recovery from a bad write

- **WHEN** the live state object is corrupted or written with values that never reached the devices, and a snapshot from before that write is promoted back to the live key
- **THEN** `tofu plan` reads the restored state and reports the drift against reality rather than a clean plan

#### Scenario: A snapshot cannot be deleted or overwritten while retained

- **WHEN** deletion of a snapshot object within its retention period is attempted with the same credential OpenTofu uses
- **THEN** the object store refuses the request and the object remains byte-identical

#### Scenario: Retention does not reach the live state

- **WHEN** an apply writes state while a retention rule is in force over the snapshot prefix
- **THEN** the write succeeds, because neither the live state object nor its lock object falls under that prefix

#### Scenario: Snapshots do not accumulate forever

- **WHEN** the bucket's lifecycle configuration is inspected
- **THEN** a rule expires objects under the snapshot prefix after a bounded age, that rule is scoped to the snapshot prefix only, and its age exceeds the retention period so that retention cannot indefinitely suppress expiry

### Requirement: Backend credentials and the encryption key arrive through secretspec

The R2 access key, the R2 endpoint, and the state encryption passphrase SHALL be declared as secretspec secrets and SHALL NOT be present in any tracked file, in the sops tree, in the OpenTofu backend block, or in the backend configuration cached under `.terraform/`.
Every OpenTofu invocation that reaches state SHALL be entered through a `just` recipe that resolves them, and each resolution SHALL carry an access reason.
Resolution SHALL be limited to the subset of secrets OpenTofu requires, and secrets outside that subset SHALL NOT be visible to the OpenTofu process or its provider plugins.

#### Scenario: Declared secrets are reported as missing when absent

- **WHEN** `secretspec check --explain` is run with a reason and the R2 secrets are not yet populated
- **THEN** it names each missing secret without revealing any value

#### Scenario: Out-of-scope secrets do not reach OpenTofu

- **WHEN** a plan is run through its `just` recipe from a shell that exports a project secret OpenTofu has no use for
- **THEN** that secret is absent from the environment OpenTofu and its provider plugins see

#### Scenario: The repository holds no backend credential

- **WHEN** the tracked tree is searched for the R2 access key, the secret access key, or the state passphrase
- **THEN** there are no matches

#### Scenario: Recipes carry the OpenTofu defaults

- **WHEN** a plan or apply is run through its `just` recipe with extra arguments appended
- **THEN** the invocation keeps single-flight parallelism and compact warnings, and the extra arguments are passed through to OpenTofu unchanged

#### Scenario: Bare invocation does not silently diverge

- **WHEN** `tofu plan` is run without the recipe, so the environment carries no credentials
- **THEN** it fails to reach the backend, rather than falling back to a local state file
