## Purpose

Defines the cluster-hosted Happy sync relay: the encrypted session, machine, and project state it brokers between phones, browsers, and workstation daemons; the boundary that keeps agent execution off cluster nodes; the exposure contract that puts the web client behind the identity provider while leaving the API open to non-browser clients; the client-binding contract that keeps self-hosted clients from silently reaching the public Happy service; and the portability of an account's history between relays.

## ADDED Requirements

### Requirement: The relay brokers state and never executes agent work

The relay SHALL provide only session synchronization: an authenticated HTTP API, a realtime event channel, encrypted-blob persistence, and presence tracking.
It SHALL NOT spawn agent processes, execute shell commands, hold a source checkout, or originate requests to any model provider API.
Agent execution SHALL remain on machines that register with the relay through a client daemon.

#### Scenario: No model-provider traffic originates from the relay

- **WHEN** the relay pod is running and clients are driving active sessions
- **THEN** the relay makes no outbound connection to any model provider endpoint, and all provider traffic originates from the registered machine running the agent

#### Scenario: The relay holds no source code

- **WHEN** a session is active against a project on a registered machine
- **THEN** the relay's database and file storage contain no file contents from that project, only the encrypted session, message, and catalog blobs the client uploaded

#### Scenario: A machine's files are reachable only while its daemon is connected

- **WHEN** a client requests a file listing or file contents for a registered machine whose daemon is disconnected
- **THEN** the request fails rather than being served from relay-side storage, because the relay retains no copy

### Requirement: Client content is opaque to the relay

The relay SHALL store session metadata, message content, machine metadata, daemon state, artifacts, project catalog entries, and key-value entries only as client-encrypted blobs.
The relay SHALL NOT hold any key capable of decrypting them.
The relay MAY hold service tokens (provider and OAuth credentials) in a form it can decrypt, and those SHALL be encrypted at rest under a deployment-held master secret.

#### Scenario: Database inspection yields no plaintext

- **WHEN** an operator reads the relay's database directly
- **THEN** session metadata, message bodies, and project metadata are ciphertext, and no stored key in that database decrypts them

#### Scenario: Master secret is supplied by the deployment

- **WHEN** the relay starts
- **THEN** it obtains its master secret from the cluster secret store, and it SHALL fail to start rather than generate or default one

#### Scenario: Losing the master secret is a recorded consequence

- **WHEN** the master secret is rotated or lost
- **THEN** previously issued auth tokens and any stored service tokens become unusable, and this is documented as a non-recoverable outcome rather than handled by fallback

### Requirement: Self-hosted clients bind to the relay's own origin

The relay SHALL serve the Happy web client from its own origin and SHALL inject a runtime configuration into the served HTML that points the client at that same origin.
The deployment SHALL treat a missing or incorrect injected origin as a deployment defect, because the web client's built-in fallback targets the public Happy service.
The deployment SHALL record that the client's voice feature resolves its server independently and defaults to the public service, since the relay has no means to override that choice.

#### Scenario: Web client targets the relay

- **WHEN** the web client is loaded from the relay's public hostname
- **THEN** its API and realtime connections go to that same hostname, and no request is made to the public Happy service

#### Scenario: Missing injection is caught before release

- **WHEN** the served HTML does not carry the injected origin configuration
- **THEN** the deployment is treated as failed, rather than serving a client that silently falls back to the public Happy service

#### Scenario: Analytics are off for the self-hosted client

- **WHEN** the web client is served by the relay
- **THEN** the injected configuration disables analytics regardless of what was compiled into the client bundle

#### Scenario: Voice server default is a recorded exposure

- **WHEN** a client is bound to the relay but its "use custom server for voice" setting is off
- **THEN** voice-token requests go to the public Happy service, and the cutover procedure enables that setting on every client as a documented step rather than assuming the binding covers it

### Requirement: Persistence is external and survives pod replacement

The relay SHALL persist relational state in a cluster-managed PostgreSQL database rather than an embedded store, and SHALL persist uploaded assets on a durable volume.
Schema migrations SHALL be applied as a step that completes before a new relay version begins serving.

#### Scenario: State survives a rollout

- **WHEN** the relay pod is deleted and rescheduled
- **THEN** existing accounts, sessions, machines, and message history remain available to clients

#### Scenario: Migration precedes serving

- **WHEN** a relay image carrying new schema migrations is rolled out
- **THEN** migrations are applied to completion first, and the new pod does not serve traffic until they succeed

#### Scenario: Failed migration blocks the rollout

- **WHEN** a migration fails
- **THEN** the rollout stops and the previously running version is left serving, rather than a pod starting against a half-migrated schema

#### Scenario: Uploaded assets outlive the pod

- **WHEN** a client has uploaded an avatar or attachment and the pod is replaced
- **THEN** the asset is still served afterward

### Requirement: The relay API is reachable by non-browser clients

The relay SHALL be exposed over TLS at a stable public hostname.
Every API, realtime, file, and health path SHALL reach the relay without passing through a browser-redirect-based authentication proxy, because the CLI daemon, mobile, and desktop clients cannot complete such a flow.
Authentication on those paths SHALL remain the relay's own public-key challenge scheme.

#### Scenario: CLI daemon authenticates directly

- **WHEN** a workstation daemon is configured against the relay's public hostname
- **THEN** it completes the public-key challenge and registers its machine without any browser interaction

#### Scenario: Mobile client connects from outside the LAN

- **WHEN** the mobile client connects from a network outside the lab LAN
- **THEN** it reaches the relay over TLS and establishes its realtime connection

#### Scenario: API paths carry no identity-provider gate

- **WHEN** a request without an identity-provider session cookie is made to an API, realtime, file, or health path on the relay's hostname
- **THEN** it is answered by the relay (success, or the relay's own 401), never redirected to the identity provider

#### Scenario: Health is observable to the cluster

- **WHEN** the cluster probes the relay's health endpoint
- **THEN** the endpoint reports healthy only while the relay's database connection is usable

### Requirement: The web client is gated by the identity provider

The relay's web client document SHALL be served only to a browser holding a valid identity-provider session, through the same forward-auth mechanism as every other browser application on the gateway, and the application SHALL be registered with the identity provider.
The deployment SHALL record that this gate covers only delivery of the web client and is not the relay's security boundary.

#### Scenario: Unauthenticated browser is redirected

- **WHEN** a browser without an identity-provider session requests the relay's root document
- **THEN** it is redirected into the identity-provider login flow, and the web client is not served

#### Scenario: Authenticated browser reaches a working client

- **WHEN** a browser with a valid identity-provider session loads the web client
- **THEN** the client is served, and its subsequent API and realtime calls to the same hostname succeed without further identity-provider involvement

#### Scenario: The gate does not restrict registration

- **WHEN** the identity-provider gate is in place
- **THEN** the relay's authentication endpoint remains reachable without an identity-provider session, and the open-registration exposure below is unchanged

### Requirement: Open registration is a recorded exposure

The relay SHALL be understood as multi-tenant with no first-client lockout: any party reaching its authentication endpoint can create an account.
The deployment SHALL record this as an accepted consequence of public exposure rather than implying a restriction it does not enforce.

#### Scenario: An unknown party can create an account

- **WHEN** an unknown party posts a valid signed challenge to the relay's auth endpoint
- **THEN** an account is created, and this is the documented expected behavior

#### Scenario: A stranger's account reaches nothing

- **WHEN** such an account exists but has paired no machine
- **THEN** it can read no other account's sessions, messages, or machines

### Requirement: Metrics are served on a dedicated in-cluster port

The relay SHALL expose Prometheus-format metrics on a port separate from its API port, reachable within the cluster and not routed through the gateway.

#### Scenario: Metrics endpoint answers in-cluster

- **WHEN** an in-cluster client requests the metrics path on the relay's metrics port
- **THEN** it receives Prometheus text-format output containing the relay's request and database metrics

#### Scenario: Metrics are not exposed publicly

- **WHEN** the metrics path is requested through the relay's public hostname
- **THEN** it is not served by the metrics listener

### Requirement: The relay image is built from this repository and consumed by digest

The relay's container image SHALL be built from a self-contained context under the cluster manifest tree's image directory, published to a registry, and referenced from manifests by an immutable tag-plus-digest pair, never by a floating tag alone.

#### Scenario: Build context is self-contained

- **WHEN** the image is built
- **THEN** the build succeeds with its own directory as the sole context and requires no file from elsewhere in the repository

#### Scenario: Workloads pin a digest

- **WHEN** a manifest references the image
- **THEN** the reference carries both a version tag and a digest, matching the pinning convention used for third-party images in the same tree

### Requirement: Account history is portable between relays

An account's machines, projects, sessions, messages, and key-value entries SHALL be copyable from one relay to another by a client holding the account's keypair, without decryption, because the content is ciphertext the relay never interprets and the account identity is the keypair.
The copy SHALL be idempotent with respect to the relay's own deduplication keys.

#### Scenario: Same keypair is the same account

- **WHEN** a client authenticates to the new relay with the keypair it used on the public service
- **THEN** it obtains an account on the new relay, and blobs encrypted for the original account are readable by that client once copied

#### Scenario: Copied history is intact and ordered

- **WHEN** the account's sessions and messages have been copied to the new relay
- **THEN** every session is present under its original tag with its message history in the original order, readable in the web and mobile clients

#### Scenario: Re-running the copy duplicates nothing

- **WHEN** the copy is run a second time against the same source and destination
- **THEN** no session or message is duplicated, because the relay matches sessions on tag and messages on local id

#### Scenario: Resume follows the moved history

- **WHEN** a workstation's locally recorded session ids are remapped to their new relay ids after the copy
- **THEN** resuming one of those sessions by id attaches to the copied session on the new relay
