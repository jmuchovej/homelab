## Purpose

Defines how compute nodes in a datacenter attach storage served by that datacenter's NAS (today: da-gr75 serving da-vcx-1 and da-vcx-2), such that the NAS being unreachable degrades user sessions and workloads but never a node's boot, activation, system services, or break-glass access.

## ADDED Requirements

### Requirement: NAS storage is never a boot or activation dependency

A host SHALL NOT place any path the operating system or the break-glass account needs on a NAS mount: `/`, `/nix`, `/var`, `/etc`, `/boot`, `/home`, `/root`, `/persist`, and `/lab`.
The NFS service aspect SHALL reject a configuration that declares a boot-time NFS mount at any of these paths.
Boot-time NFS mounts at other paths (such as `/srv/media`) remain permitted and SHALL continue to carry the existing non-blocking options (`nofail`, automount with a bounded mount timeout).

#### Scenario: Forbidden mountpoint is rejected at evaluation

- **WHEN** a host declares an `nfs.mounts` entry whose `local` is `/home`
- **THEN** evaluating that host's configuration fails with an assertion naming the path and this requirement

#### Scenario: Activation succeeds with the NAS unreachable

- **WHEN** a da compute node's NAS export is unreachable and a new system generation is activated (switch or boot)
- **THEN** activation completes, every system service that was running before is running after, and no unit reports a `NAMESPACE` failure referencing `/home`

#### Scenario: Break-glass login with the NAS unreachable

- **WHEN** the NAS export is unreachable
- **THEN** the `lab` account can log in over SSH, lands in `/lab`, and deploy-rs can activate a generation through it

### Requirement: Directory users receive their NAS home per session

On a host with `nfs.homes` configured, each login session for a directory user SHALL have that user's NAS home directory mounted at `/home/<user>` for the lifetime of the session, and the mount SHALL be released when the user's last session on the host ends.
A directory user is any account that is not declared in the host's static user set and is not a system account (uid below 1000).
Declared local accounts (including `lab` and `root`) SHALL NOT receive a NAS home.
The host SHALL NOT express the per-user home as a boot-time filesystem; it SHALL appear in neither `/etc/fstab` nor the set of mount units started at boot.

#### Scenario: Directory user logs in while the NAS is reachable

- **WHEN** an SSSD-backed user opens an SSH session on da-vcx-1 and the NAS export is reachable
- **THEN** `/home/<user>` inside the session is an NFS mount of `<export>/<user>` from the NAS, and files the user created on another da node are visible

#### Scenario: Last logout releases the mount

- **WHEN** a directory user closes their last session on the host
- **THEN** `/home/<user>` is no longer an NFS mountpoint on that host

#### Scenario: Local account is unaffected

- **WHEN** `lab` logs in on a host with `nfs.homes` configured
- **THEN** no NFS mount is attempted for `lab` and its home remains the local `/lab`

#### Scenario: No boot-time trace of user homes

- **WHEN** the host's generated `/etc/fstab` and the list of mount units wanted by `local-fs.target` and `remote-fs.target` are inspected
- **THEN** no entry references `/home` or any path beneath it

### Requirement: Login is refused when a directory user's home cannot be attached

If a directory user's NAS home cannot be mounted at login, the host SHALL refuse the session rather than admit the user to a local directory at the same path.
The refusal SHALL be logged with the user name and the reason on the host.
Local accounts SHALL NOT be subject to this gate.

#### Scenario: NAS unreachable at login

- **WHEN** an SSSD-backed user attempts an SSH login and the NAS export is unreachable
- **THEN** the session is not opened, the client sees the connection closed after authentication, and the host journal records that the home for that user was not mounted

#### Scenario: Home missing on the NAS

- **WHEN** an SSSD-backed user whose per-user home does not yet exist on the export attempts to log in
- **THEN** the session is refused, the journal identifies the missing home as the reason, and a retry after one provisioning interval succeeds without any administrator action

#### Scenario: Gate does not apply to local accounts

- **WHEN** `lab` logs in while the NAS export is unreachable
- **THEN** the session opens normally

### Requirement: NAS outage is confined to sessions that use it

A NAS outage occurring while directory users have sessions open SHALL affect only those sessions.
Processes blocked on the unavailable home SHALL remain terminable by a fatal signal, new local-account sessions SHALL open normally, and system services SHALL keep running.

#### Scenario: Outage during an open session

- **WHEN** the NAS becomes unreachable while a directory user has processes running under `/home/<user>`
- **THEN** those processes block, `kill -9` terminates them, a concurrent `lab` SSH login succeeds, and the node's Kubernetes node condition stays Ready

### Requirement: The NAS provisions a home for every directory user

A NAS node with home provisioning configured SHALL ensure that every directory user known to it has a home under the home export, created as a ZFS dataset named after the user, within one provisioning interval (five minutes by default) of the user becoming known.
On creation the dataset SHALL carry the configured default quota (1 TB by default), POSIX ACL support, ownership by the user's uid and primary gid, mode `0700`, and a copy of the skeleton directory.
Provisioning SHALL be create-only: it SHALL NOT destroy, rename, or move a dataset, and it SHALL NOT re-apply quota, ownership, or mode to a dataset that already exists.
It SHALL NOT create a dataset where a plain directory already occupies the user's path; it SHALL log that path instead.
A directory user is defined as for session mounts: not declared in the NAS's static user set and not a system account.

#### Scenario: New authentik user

- **WHEN** a user is created in authentik and SSSD on the NAS has enumerated it
- **THEN** within one interval a dataset `<export-dataset>/<user>` exists, mounted under the export, owned by that user's uid and gid, mode `0700`, with `quota` equal to the configured default and the skeleton files present

#### Scenario: Per-user quota raised by hand

- **WHEN** an administrator sets a larger `quota` on an existing user's dataset
- **THEN** subsequent provisioning runs leave that quota, the ownership, and the mode unchanged

#### Scenario: User removed from authentik

- **WHEN** a user no longer appears in the directory
- **THEN** their dataset and its contents remain on the NAS untouched

#### Scenario: Legacy directory in the way

- **WHEN** a directory user's path under the export exists as a plain directory rather than a dataset
- **THEN** provisioning skips that user, logs the path as needing migration, and continues with the remaining users

#### Scenario: Local NAS accounts

- **WHEN** provisioning runs on a NAS whose static users are `lab` and root
- **THEN** no dataset is created for either

### Requirement: Per-node scope follows topology

`nfs.homes` SHALL be configured only on compute nodes in a datacenter that has a dedicated NAS node, and home provisioning SHALL be configured only on that NAS node.
A host without `nfs.homes` SHALL behave exactly as before this capability existed: directory users get a locally created home.

#### Scenario: Single-node datacenter

- **WHEN** en-t65-1's configuration is evaluated
- **THEN** it has no `nfs.homes`, no home provisioning, no pam_mount volume for `/home`, and no login gate
