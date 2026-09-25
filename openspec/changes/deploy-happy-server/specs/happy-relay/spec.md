## Purpose

Defines the cluster-hosted Happy sync relay: the encrypted session, machine, and
project state it brokers between phones, browsers, and workstation daemons; the
boundary that keeps agent execution off cluster nodes; and the exposure and
client-binding contract that keeps self-hosted clients from silently reaching
the public Happy service.

## ADDED Requirements

### Requirement: The relay brokers state and never executes agent work

The relay SHALL provide only session synchronization: an authenticated HTTP API,
a realtime event channel, encrypted-blob persistence, and presence tracking. It
SHALL NOT spawn agent processes, execute shell commands, hold a source checkout,
or originate requests to any model provider API. Agent execution SHALL remain on
machines that register with the relay through a client daemon.

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

The relay SHALL store session metadata, message content, machine metadata,
daemon state, artifacts, project catalog entries, and key-value entries only as
client-encrypted blobs. The relay SHALL NOT hold any key capable of decrypting
them. The relay MAY hold service tokens (provider and OAuth credentials) in a
form it can decrypt, and those SHALL be encrypted at rest under a deployment-held
master secret.

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

The relay SHALL serve the Happy web client from its own origin and SHALL inject a
runtime configuration into the served HTML that points the client at that same
origin. The deployment SHALL treat a missing or incorrect injected origin as a
deployment defect, because the web client's built-in fallback targets the public
Happy service.

#### Scenario: Web client targets the relay

- **WHEN** the web client is loaded from the relay's public hostname
- **THEN** its API and realtime connections go to that same hostname, and no request is made to the public Happy service

#### Scenario: Missing injection is caught before release

- **WHEN** the served HTML does not carry the injected origin configuration
- **THEN** the deployment is treated as failed, rather than serving a client that silently falls back to the public Happy service

#### Scenario: Analytics are off for the self-hosted client

- **WHEN** the web client is served by the relay
- **THEN** the injected configuration disables analytics regardless of what was compiled into the client bundle

### Requirement: Persistence is external and survives pod replacement

The relay SHALL persist relational state in a cluster-managed PostgreSQL
database rather than an embedded store, and SHALL persist uploaded assets on a
durable volume. Schema migrations SHALL be applied as a step that completes
before a new relay version begins serving.

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

### Requirement: The relay is reachable by non-browser clients

The relay SHALL be exposed over TLS at a stable public hostname. The exposure
SHALL NOT interpose a browser-redirect-based authentication proxy, because the
CLI daemon, mobile, and desktop clients cannot complete such a flow.
Authentication SHALL remain the relay's own public-key challenge scheme.

#### Scenario: CLI daemon authenticates directly

- **WHEN** a workstation daemon is configured against the relay's public hostname
- **THEN** it completes the public-key challenge and registers its machine without any browser interaction

#### Scenario: Mobile client connects from outside the LAN

- **WHEN** the mobile client connects from a network outside the lab LAN
- **THEN** it reaches the relay over TLS and establishes its realtime connection

#### Scenario: Health is observable to the cluster

- **WHEN** the cluster probes the relay's health endpoint
- **THEN** the endpoint reports healthy only while the relay's database connection is usable

### Requirement: Open registration is a recorded exposure

The relay SHALL be understood as multi-tenant with no first-client lockout: any
party reaching its authentication endpoint can create an account. The deployment
SHALL record this as an accepted consequence of public exposure rather than
implying a restriction it does not enforce.

#### Scenario: An unknown party can create an account

- **WHEN** an unknown party posts a valid signed challenge to the relay's auth endpoint
- **THEN** an account is created, and this is the documented expected behavior

#### Scenario: A stranger's account reaches nothing

- **WHEN** such an account exists but has paired no machine
- **THEN** it can read no other account's sessions, messages, or machines
