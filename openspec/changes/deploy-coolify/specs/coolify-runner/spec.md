## Purpose

Defines a Coolify runner: the disposable virtual machine on which deployed applications are built and run, what it may and may not contain, how it is identified and reached, and the invariant that every runner is interchangeable and none is precious.

## ADDED Requirements

### Requirement: A runner is a virtual machine and nothing else runs the workloads

Every host that executes Coolify-dispatched work SHALL be a virtual machine guest on a compute node.
No Coolify-dispatched command SHALL execute on a hypervisor or on a cluster node.

#### Scenario: Compromise is bounded by the guest

- **WHEN** an arbitrary command is executed as root on a runner
- **THEN** it has no access to the hypervisor's filesystem, process namespace, or the cluster node's credentials

#### Scenario: One runner per compute node

- **WHEN** a compute node is configured to host a runner
- **THEN** exactly one runner guest exists on it, named after that node's suffix

### Requirement: A runner contains only what dispatch requires

A runner SHALL provide a Docker daemon, an SSH daemon, the command-line tools Coolify's generated commands invoke, and a writable data directory for Coolify.
A runner SHALL NOT mount lab storage, hold decryption keys or secrets of its own, join any overlay or VPN network, or carry user accounts beyond those required to administer it.

#### Scenario: Nothing to find

- **WHEN** a runner's filesystem is enumerated as root
- **THEN** no secret material, no network share, and no credential for any other system is present

#### Scenario: Required tooling is present

- **WHEN** Coolify validates a newly registered runner
- **THEN** it finds a usable Docker daemon and installs nothing

### Requirement: Access is root over SSH with exactly one authorized key

A runner SHALL accept SSH as root using key authentication only.
Password authentication SHALL be disabled.
Root's authorized keys SHALL contain exactly one key: the fleet key whose public half is committed to the repository beside the runner definition.

#### Scenario: Only the fleet key opens a runner

- **WHEN** an SSH connection as root is attempted with any key other than the fleet key
- **THEN** it is refused

#### Scenario: No password path

- **WHEN** an SSH connection is attempted with a password
- **THEN** it is refused before any password is checked

#### Scenario: Public key matches the committed private key

- **WHEN** the committed public key is compared to the fingerprint of the encrypted private key the control plane loads
- **THEN** they are the same keypair

### Requirement: Runner identity is deterministic and stable

A runner SHALL have a hostname of the form `<site>-cfy-<N>`, where `N` is the suffix of the compute node hosting it.
Its network address SHALL be stable across rebuilds and reboots, pinned to a hardware address derived deterministically from its name.

#### Scenario: Rebuild keeps the address

- **WHEN** a runner's guest definition is rebuilt from the repository and the guest restarted
- **THEN** it comes back with the same hardware address and the same network address

#### Scenario: Name follows the node

- **WHEN** a runner is declared on compute node `da-vcx-3`
- **THEN** its hostname is `da-cfy-3` and its development URL wildcard is `*.cfy-3` under the site domain

### Requirement: A runner is disposable

Destroying a runner and re-minting it from the repository SHALL require no change to the control plane beyond re-validating the server.
No runner SHALL be configured differently from another except in name and address.
No data that must survive SHALL live only on a runner.

#### Scenario: Re-mint without control plane edits

- **WHEN** a runner's disk is deleted and the guest is reinstalled from the repository
- **THEN** the control plane reconnects with its existing key and the server record, and redeploying an application restores it

#### Scenario: No special runner

- **WHEN** two runners' configurations are compared
- **THEN** they differ only in hostname, hardware address, and network address

### Requirement: The container network avoids every lab and cluster range

A runner's Docker daemon SHALL allocate container networks from a range that does not overlap the cluster pod range, the cluster service range, any site LAN, or the management network.

#### Scenario: No overlap with routed ranges

- **WHEN** the runner's container address pool is compared to the cluster and site address plans
- **THEN** no range intersects

### Requirement: A runner accepts traffic only from the cluster

A runner SHALL need inbound connections only on its SSH port from the control plane and on port 80 from the cluster's ingress and tunnel connector.
A runner SHALL NOT require any inbound connection from the public internet.

#### Scenario: No public exposure needed

- **WHEN** a runner has no route from the internet
- **THEN** every deployed application on it remains reachable through its development URL and any vanity hostname

#### Scenario: Inbound set is small

- **WHEN** the runner's required inbound flows are enumerated
- **THEN** they are SSH from the control plane and HTTP from the cluster, and nothing else

### Requirement: The hypervisor declares the guest, the repository defines it

The compute node's configuration SHALL declare only the guest's existence: identity, resources, disk, and network attachment.
The guest's operating system configuration SHALL be a host definition in the repository, built and deployed like any other host.

#### Scenario: Guest is a first-class host

- **WHEN** the repository's host configurations are built
- **THEN** each runner builds as its own system, independently of the hypervisor's configuration

#### Scenario: Hypervisor carries no guest internals

- **WHEN** the compute node's configuration is inspected
- **THEN** it contains no runner secrets, no runner-side service configuration, and no runner filesystem contents
