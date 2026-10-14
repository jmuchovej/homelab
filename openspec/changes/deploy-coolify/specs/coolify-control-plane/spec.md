## Purpose

Defines the cluster-hosted Coolify control plane: the dispatcher that holds the fleet's credentials and sends work to runners, what it must never execute itself, how its state and secrets are supplied, how its version is pinned, and where it is reachable from.

## ADDED Requirements

### Requirement: The control plane dispatches and never executes

The control plane SHALL perform every deployment, build, container, and proxy operation by sending commands over SSH to a registered runner.
It SHALL NOT have access to a container runtime socket on the node it runs on, and no application, database, or service managed through it SHALL run on a cluster node.

#### Scenario: No runtime socket is mounted

- **WHEN** the control plane pods are inspected
- **THEN** none of them mounts a container runtime socket from the node, and none of them carries a privilege that would let it start containers on the node

#### Scenario: A deployment with no reachable runner does nothing locally

- **WHEN** a deployment is triggered while every registered runner is unreachable
- **THEN** the deployment fails with a connection error and no container, image, or build artifact appears on any cluster node

#### Scenario: The built-in local server is never a target

- **WHEN** an application, database, or service is created
- **THEN** it can be assigned only to a registered runner, and the control plane's own built-in "localhost" server has no deployable resources

### Requirement: The control plane holds no state outside its database

The control plane SHALL keep every durable fact — teams, servers, keys, applications, environments, deployment history — in a cluster-managed PostgreSQL database.
It SHALL NOT claim a persistent volume.
Replacing a control plane pod SHALL lose at most the queued jobs that were in flight.

#### Scenario: Pod replacement preserves configuration

- **WHEN** every control plane pod is deleted and rescheduled
- **THEN** every registered runner, stored key, application, and environment variable is present afterwards without operator action

#### Scenario: In-flight work is the only loss

- **WHEN** a deployment is mid-flight and the worker pod is replaced
- **THEN** that deployment is marked failed or re-queued, and no other application's state changes

#### Scenario: No persistent volume claims

- **WHEN** the control plane's namespace is inspected
- **THEN** the only persistent volume claims belong to the database, and the control plane workloads own none

### Requirement: Instance secrets are supplied, never generated

The control plane SHALL obtain its application encryption key, realtime credentials, cache password, and database credentials from the cluster secret store at start.
It SHALL NOT generate any of them, SHALL NOT write any of them to a file it manages, and SHALL fail to start rather than run with a defaulted or empty encryption key.

#### Scenario: Missing encryption key blocks start

- **WHEN** the application encryption key is absent from the supplied configuration
- **THEN** the control plane does not serve requests and reports the missing value

#### Scenario: Secrets have one source

- **WHEN** an instance secret is rotated in the secret store
- **THEN** the control plane picks up the new value on its next start, and no other copy of the value exists in a manifest, a volume, or a generated file

### Requirement: The version is pinned and changed only by commit

The control plane SHALL run an image identified by digest.
Its built-in self-update SHALL be disabled, and no path other than a change to the committed digest SHALL alter the running version.
All control plane roles SHALL run the same version at all times.

#### Scenario: Self-update is inert

- **WHEN** a newer upstream release is published
- **THEN** the running version does not change, and the control plane's own update mechanism reports updates as disabled

#### Scenario: Roles never skew

- **WHEN** the committed digest changes and the rollout completes
- **THEN** the web, worker, and scheduler roles all run the new digest, and at no point does one role run the new digest while another serves work from the old one

### Requirement: Roles are separately restartable units of one release

The control plane SHALL run its web interface and API, its background workers, and its scheduler as separately restartable units.
Exactly one scheduler instance SHALL run at any time.
A restart of the background workers SHALL NOT interrupt the web interface.

#### Scenario: Worker restart leaves the UI up

- **WHEN** the background worker unit restarts
- **THEN** the web interface continues to answer requests throughout

#### Scenario: Scheduled work runs once

- **WHEN** a scheduled task fires
- **THEN** it executes exactly once per schedule tick, not once per control plane unit

### Requirement: The runner key enters through the key store from a committed source

The private key that authenticates the control plane to runners SHALL be loaded into the control plane's key store from a source that is committed, encrypted, to the repository and decrypted only inside the cluster.
The private key SHALL NOT appear in plaintext in any manifest, values file, or image.
One keypair SHALL serve the whole fleet.

#### Scenario: Key loading is repeatable

- **WHEN** the key-loading step runs against a control plane that already holds the key
- **THEN** it completes without creating a duplicate and without error

#### Scenario: Key survives database restore

- **WHEN** the database is restored from backup together with the application encryption key
- **THEN** the control plane can reach every runner without the key being loaded again

#### Scenario: Plaintext never lands in the tree

- **WHEN** the repository is searched for the private key material
- **THEN** it is found only inside an encrypted file

### Requirement: Access is gated by the identity provider

The control plane's web interface and realtime channel SHALL be reachable only through an edge gate that defers to the cluster's identity provider, and an unauthenticated request SHALL be sent to the identity provider's login rather than reaching the control plane.
Git-provider webhooks SHALL bypass the edge gate and SHALL be accepted only with a valid provider signature; they SHALL be the only surface reachable from outside operator-controlled networks without an identity session.
The in-browser terminal, the API, and operational endpoints SHALL additionally be reachable only from operator-controlled networks — the site LAN, the management network, and the mesh — and SHALL be refused from anywhere else regardless of credentials.
The API SHALL authenticate every request by bearer token with scoped abilities.
Every browser-facing channel, including both websockets, SHALL be served on the control plane's single HTTPS origin; no additional port SHALL be exposed.
Interactive login SHALL use the identity provider, and account self-registration SHALL be disabled once that login is configured.
The control plane SHALL NOT be reachable through the tunnel used for deployed applications.

#### Scenario: Anonymous request never reaches the control plane

- **WHEN** the web interface's hostname is requested without an identity-provider session, from anywhere
- **THEN** the response is a redirect to the identity provider's login, and the control plane serves nothing

#### Scenario: Realtime works behind the gate

- **WHEN** an authenticated user loads the web interface from anywhere
- **THEN** its realtime channel connects over the same hostname and port through the gate, and live deployment output appears

#### Scenario: Terminal is refused from outside

- **WHEN** an authenticated user opens the in-browser terminal from a network that is not operator-controlled
- **THEN** the terminal connection is refused and no shell is started

#### Scenario: Terminal works from inside

- **WHEN** an authenticated user opens the in-browser terminal from the site LAN or the mesh
- **THEN** the terminal connects over the same hostname and port and a shell is available

#### Scenario: API is refused from outside despite a valid token

- **WHEN** an API request carrying a valid bearer token arrives from a network that is not operator-controlled
- **THEN** it is refused before the token is evaluated

#### Scenario: API is token-gated from inside

- **WHEN** an API request carries a valid bearer token and no identity-provider session, from an operator-controlled network
- **THEN** it is served according to the token's abilities

#### Scenario: API without a token is refused by the control plane

- **WHEN** an API request from an operator-controlled network carries no bearer token
- **THEN** the control plane itself answers with an authentication error, and no redirect to the identity provider occurs

#### Scenario: Signed webhook triggers a deployment

- **WHEN** a git provider posts a push event with a valid signature and no identity-provider session
- **THEN** the matching application's deployment starts

#### Scenario: Unsigned webhook is rejected

- **WHEN** a push event arrives with a missing or invalid signature
- **THEN** it is rejected and no deployment starts

#### Scenario: Login is single sign-on

- **WHEN** a user who passed the gate reaches the control plane's login
- **THEN** they sign in through the identity provider without a control-plane password

#### Scenario: Registration is closed

- **WHEN** a visitor opens the registration page after identity-provider login is configured
- **THEN** no account can be created

#### Scenario: Not on the application tunnel

- **WHEN** the application tunnel's rules are listed
- **THEN** none routes to the control plane

### Requirement: Restoring the database and encryption key restores the instance

The complete disaster-recovery set for the control plane SHALL be the database plus the application encryption key.
Restoring both to a fresh deployment SHALL yield a working instance with every runner reachable and every application's configuration intact.

#### Scenario: Fresh deployment from backup

- **WHEN** the control plane is deployed from scratch against a restored database with the original encryption key supplied
- **THEN** every runner, application, and stored environment variable is present and usable

#### Scenario: Backup without the key is unusable

- **WHEN** the control plane is deployed against a restored database with a different encryption key
- **THEN** stored keys and environment variables cannot be decrypted, and this is the documented reason the key is kept as long as the database exists
