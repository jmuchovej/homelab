# syncthing — one instance per user

Syncthing has no multi-tenancy: one instance is one device identity, one config, one GUI, one admin. Per-user therefore means per-_deployment_, so this is a parameterised component consumed as the `spec.path` of `apps/home/syncthing/syncthing-<key>.ks.yaml` (the `cnpg-database` shape), not an app directory.

Everything is keyed on the opaque authentik user key (`ypah-xuuk`, …), never a username — the same obfuscation the sops user records buy. The key reaches resource names, the hostname, the dataset path, and the 1Password field names; the key→person mapping exists only in sops.

| Variable       | Meaning                                                                  |
| -------------- | ------------------------------------------------------------------------ |
| `ST_KEY`       | authentik user key — names every resource, the hostname, and the dataset |
| `ST_DB_SIZE`   | PVC size for config + SQLite index (scales with file COUNT, not bytes)   |
| `ST_MEM_LIMIT` | container memory limit — the index is held largely in memory             |
| `ST_LB_IP`     | LB-IPAM address for the sync protocol; convention `10.69.1.7x`           |

Adding a user is a new `ks.yaml`, a line in that directory's `kustomization.yaml`, a `syncthing.instances` entry on da-gr75, **and** a redirect rule in `entry/http-route.yaml` — the entry point cannot derive its rules from the ks files.

## Ownership, quota, and why no uid appears here

Every instance runs as a fixed `8384:8384`. Carrying the _human's_ uid would mean the same number living here and in `secrets/users.sops.yaml`, with nothing enforcing agreement — so it isn't carried at all. The owner reaches their own tree through a POSIX ACL instead, and `secrets/users.sops.yaml` stays the single source of that number: tofu reads it for authentik (whose LDAP provider serves it to the hosts), and `<rbn/services/syncthing/datasets>` reads the same file through sops-nix. Set `uidNumber`/`gidNumber` there as **strings** — per goauthentik#9533 an integer `gidNumber` is honoured on the user object but silently ignored on the virtual group.

That nix aspect — `<rbn/system/hardware/storage/zfs/datasets>`, generic dataset provisioning rather than anything Syncthing-specific — owns everything about the tree. da-gr75 declares one `zfs.datasets` entry per key with a `quota`, `acltype=posixacl`, owner `8384:8384`, mode `2770` (setgid, so entries the human creates stay group-owned by syncthing) and `acl-users = [ <key> ]`, which becomes `u:<uid>:rwx` plus the matching `d:` defaults. It orders itself `before = [ "k3s.service" ]` so no pod can start against an unprovisioned tree, and fails activation if a key's `uidNumber` is missing or non-numeric rather than silently mis-owning data.

`ST_DB_SIZE` bounds **only** the config + index PVC. The sync data is bounded by the ZFS `quota` on the dataset — without it a `hostPath` has no ceiling and one user can fill `impulse`. (zfs-localpv would also give a quota, since `fstype: zfs` provisions a DATASET with `quotaType: quota`, but its volume lands at an opaque `impulse/k8s/pvcs/pvc-<uuid>` that can't be stably bind-mounted into a home directory.)

## Why it is pinned to da-gr75

The design rests on the sync tree being a **local** ZFS path. `da-gr75` owns `impulse/`; every other node sees the same storage only as the NFS re-export. Running elsewhere would cost two things:

- **SQLite over NFS.** Syncthing 2.x replaced LevelDB with SQLite for the index. NFS locking corrupts it, and Syncthing has long-standing lock-file failures with even its config directory on NFS. `STCONFDIR`/`STDATADIR` therefore both point at the local PVC (`zfs-hdd`, not the default `zfs-ssd`, which provisions from `warp/` on da-vcx-1) and _only_ the synced data comes from `hostPath`.
- **Change detection.** inotify on an NFS client never fires for writes made by another client, so an NFS-mounted instance is blind to anything written directly on the NAS and must fall back to timed full rescans.

The tree lives at `/impulse/syncthing/<key>` rather than inside a home directory so that no username appears in this repo. Re-exposing it at `~/Syncthing` is a NAS-side bind mount (not a symlink — a symlink on the export resolves client-side, where `/impulse` does not exist; the export's existing `crossmnt` is what lets NFSv4 traverse the bind).

Consequence: these releases are hard-down whenever `da-gr75` is out of the cluster. That is the same blast radius the NFS `/home` mount already imposes on da-vcx-1.

## Access control

Two surfaces, deliberately gated differently:

- **`syncthing.${DC_DOMAIN}`** (`apps/home/syncthing/entry/`) — the memorable entry point. Gated by the `syncthing` **group**, and it grants nothing: every rule is a 302 to a per-user subdomain that re-authorises independently.
- **`syncthing-<key>.${DC_DOMAIN}`** — gated by a direct **user** binding (`authentik.rbn/access: user:<key>`). A group here would let any member open any other member's GUI. This is the "until it's absolutely necessary" carve-out; prefer groups everywhere else.

The entry point selects its redirect from `x-authentik-username`, which requires `extAuth.recomputeRoute: true` — Envoy picks a route _before_ ext-auth runs, so without it the rules would match whatever the client sent. The initial match is on the unauthenticated header, but that is harmless here: the only thing an initial match can do is choose a redirect, and the destination gates independently. Do not reuse this pattern to select a _backend_ without re-reading Envoy's ext_authz notes on route-cache clearing.

Redirects are 302, never 301 — the target depends on who is logged in, so a permanent redirect would be cached by the browser and send the next user to the wrong instance.

The GUI's own auth is unset: the proxy outpost is the gate. That gate is only on the _route_ — anything already inside the cluster can reach `:8384`. A `CiliumNetworkPolicy` restricting it to the Envoy pods is the real fix and is tracked with the rest of the deferred netpol work; note that an allow-all CNP is not a no-op (it flips endpoints into enforcement).

The frozen entry's `skip_paths = "/rest/*"` was deliberately **not** carried over. Syncthing's GUI drives `/rest/*` over XHR with the session cookie, so it passes ext-auth normally; exempting it would leave each instance's API unauthenticated.

## Identity

The device keypair comes from 1Password item `Syncthing` (vault `Homelab`), fields `<datacenter>-<key>-cert` / `<datacenter>-<key>-key`, and an init container installs it into the config dir before Syncthing starts. Without this the identity would live only on the PVC, and losing the PVC would mint a new device ID that every paired device has to re-trust.

Group the fields into per-datacenter **sections** for readability if you like, but the datacenter must stay in the _label_ too: the `onepassword` (Connect) provider resolves `remoteRef.property` against field labels flat across the item and has no section syntax, so two fields labelled `da-…`/`en-…` identically in different sections would collide. Only the `onepasswordSDK` provider addresses sections (`<item>/[section/]<field>`), and switching to it is a cluster-wide provider swap, not a per-secret choice.

Mint one with `syncthing generate --config "$d" --data "$d"`, then lift `$d/cert.pem` and `$d/key.pem`; discard the `config.xml` it also writes. The device ID is derived from the certificate, so it is never stored — `syncthing device-id --config "$d"` recomputes it from the pems at any time.

**One keypair per (user × cluster), never shared.** A Syncthing identity _is_ the instance: two running instances holding the same certificate present the same device ID, and Syncthing will not connect to its own ID, so they could never sync with each other and any third device would see one ID on two conflicting connections. `${DATACENTER}` scopes the 1Password item for exactly this reason.

## Deliberate non-configuration

Folders and peer devices are **not** declared here — that is the point of per-user instances, and each user drives their own GUI. Versus the NixOS service this replaces (`modules/services/syncthing/`), which pinned everything: global discovery and relays now default to **on** (the NixOS module disabled both, since all peers were pinned by address and relaying block exchange through the public relays is a ToS problem). Turn them off per instance in Settings, or accept them as the off-LAN path. `STNODEFAULTFOLDER` is set, so a fresh instance starts empty rather than creating `~/Sync`.
