## Context

See proposal.md for motivation.
Facts that shape the approach, all verified against the tree and the pinned nixpkgs (`bd3bac8b`):

- **Who logs in.** On da-vcx-1 and da-vcx-2 the static user set is `lab` (home `/lab`, `users.mutableUsers = false`) plus root.
  Every other account comes from SSSD against authentik LDAP (`modules/services/ldap.nix`): `fallback_homedir = /home/%u`, `filter_users = root,lab`, `cache_credentials = true`, `auto_private_groups = true`.
  Both the NAS and the nodes run the same SSSD config, so uids agree across NFS without idmapd games.
  `security.pam.services.{sshd,login}.makeHomeDir = true` is already set there.
- **What the NFS aspect does today.** `modules/services/nfs.nix` turns `host.nfs.mounts` into `fileSystems.*` entries with `nfsvers=4.2,_netdev,noatime,hard,x-systemd.automount,x-systemd.mount-timeout=10s,x-systemd.idle-timeout=600,nofail`, and excludes those mountpoints from `systemd-tmpfiles-setup`.
  da-vcx-1 now lists only `/srv/media`.
  da-vcx-2 lists `/home` **and** its `_hardware.nix` declares `fileSystems."/home"` as a local btrfs subvolume, so that host currently evaluates two definitions for one mountpoint.
- **NixOS pam_mount wiring.** `security.pam.mount.enable` writes `/etc/security/pam_mount.conf.xml` (`<debug>`, `<logout>`, `<path>` from `util-linux` plus `additionalSearchPaths`, `<mkmountpoint enable remove>`, then `extraVolumes` verbatim) and flips `pamMount` on for every PAM service.
  The session stack order is fixed by `utils.pam.autoOrderRules` at `10000 + index*100`: `mkhomedir` is index 7 (10700), `mount` index 13 (11300), `ldap` index 14 (11400), `sss` index 17, `systemd` index 20.
  `mount` runs as `optional` with `disable_interactive`.
  Custom rules are added through `security.pam.services.<svc>.rules.session.<name> = { control; modulePath; args/settings; order; }`.
- **pam_mount semantics (read from source).** `pam_sm_open_session` logs `mount of %s failed` and then unconditionally returns `PAM_SUCCESS`; there is no option to deny.
  Volumes with no user control apply to every non-root user.
  Simple attributes (`user=`, `uid=`, …) and extended elements (`<and>/<or>/<not>` over `<user>/<uid>/<gid>/<pgrp>/<sgrp>`) cannot be combined on one volume; both parse uid/gid ranges as `N-M` through the same function.
  `%(USER)` substitutes the logging-in user in `path` and `mountpoint`.
  Mounts are counted per user (`pmvarrun`) and the volume is unmounted on the last logout.
- **mount.nfs under pam_mount.** pam_mount execs `mount` from its `<path>`; `mount -t nfs` needs `mount.nfs` from `nfs-utils` on that PATH, which the aspect must add via `additionalSearchPaths`.
- **The old failure mode.** The deploy-breaking signature was entirely `/home`-as-mountpoint: `ProtectHome` units binding `/home` (226/NAMESPACE), the users activation `install -d /home`, and a wedged `home.mount` stop job.
  None of it involved `/srv/media`.
- **The NAS side.** da-gr75 includes the same `<rbn/services/ldap>` aspect, so its SSSD enumerates the directory (`enumerate = true`, default refresh 300 s) and `getent passwd` there lists every authentik user with the same uid the nodes see.
  Its static users are `lab` and root.
  It exports `/impulse/home` to the lab CIDR with `rw,sync,no_subtree_check,no_root_squash,crossmnt`; `crossmnt` is what lets an NFSv4 client traverse into child datasets.
  The homes under it today are plain directories, not datasets.
  `modules/system/hardware/storage-zfs-datasets.nix` already provisions _statically declared_ datasets (quota, owner, mode, POSIX ACLs) from a oneshot ordered before k3s; it cannot cover SSSD users because they are unknown at evaluation time.
- **Pool health.** With the `impulse` pool suspended, `zfs` commands enter uninterruptible sleep (see the HBA incident notes), and da-gr75 is not deployable until its transport is proven.

## Goals / Non-Goals

**Goals:**

- One host knob, `host.nfs.homes`, that fully describes "directory users' homes come from the NAS", with no per-user lists anywhere.
- Zero NAS references in `/etc/fstab`, in boot-time mount units, or in the activation script.
- A login that either delivers the NAS home or is refused, never a silently local home.
- A `denTest` that pins the selector (local users excluded, uid floor) and the absence of `/home` from `fileSystems`.
- A NAS-side provisioner with the same notion of "directory user" as the client-side selector and gate, so the three can never disagree about who gets a NAS home.

**Non-Goals:**

- Any change to sssd, authentik, or the NAS export options.
- `/srv/media`, the media pods, FS-Cache, or the new local 6 TB drives.
- Darwin or Windows clients of the NAS (SMB, Time Machine).

## Decisions

**D1. Session-scoped mounts via pam_mount, not fstab/autofs per user.**
Alternatives: (a) `fileSystems."/home/<user>"` automounts generated per user: needs a user list at eval time, which SSSD users do not have, and still lands in the boot transaction; (b) `services.autofs` indirect map on `/home`: no user list needed, but `/home` becomes an autofs mountpoint again, which is the exact path `ProtectHome` and the users snippet touch; (c) users mount manually or rsync: rejected in the proposal.
pam_mount needs no user list, attaches only when a session opens, and leaves `/home` a plain local directory.

**D2. Selector = extended user control, derived from config.**
The volume is written in extended form only (mixing with simple attributes is a parse error):

```xml
<volume fstype="nfs" server="<server>" path="<export>/%(USER)" mountpoint="/home/%(USER)" options="<opts>">
  <and>
    <uid>1000-4294967294</uid>
    <not><user>lab</user></not>
    <!-- one <not><user>…</user></not> per isNormalUser in config.users.users -->
  </and>
</volume>
```

The `<not><user>` list is generated from `config.users.users` filtered on `isNormalUser`, so adding a static account to a host can never accidentally give it a NAS home.
The uid floor excludes system accounts without naming them.
Alternative: `sgrp="<ldap group>"` — would couple the host to an authentik group name and silently stop matching if the group is renamed; the "not local" definition is the one the proposal states.

**D3. The gate is a `pam_exec` session rule between `mount` and `ldap`.**
Order `11350` (between `mount` 11300 and `ldap` 11400), control `required`, attached only to `sshd` and `login` (the services `ldap.nix` already shapes).
The script, generated with `pkgs.writeShellApplication`, runs as root with `PAM_USER`/`PAM_TYPE` from pam_exec:

- exit 0 unless `PAM_TYPE = open_session`;
- exit 0 if `PAM_USER` is in the baked local-user list or its uid (via `getent passwd`) is below 1000 — the same predicate as D2, so the gate and the volume can never disagree;
- otherwise exit 0 iff `mountpoint -q /home/$PAM_USER`; on failure log `nfs-homes: refusing <user>: /home/<user> is not mounted` via `logger` and exit 1.

`required` (not `requisite`) lets the rest of the session stack run and report before PAM returns failure, which gives a complete journal line from sshd (`pam_open_session failed`).
Alternatives: making `mount` itself `required` does nothing (pam_mount returns success regardless); an `account`-phase reachability probe would race the mount and cannot see whether _this_ user's directory exists.

**D4. Keep `makeHomeDir`, accept the shadowed skeleton.**
`pam_mkhomedir` runs at 10700, before `mount`, and creates a local `/home/<user>` from `/etc/skel` on first login; pam_mount then mounts over it.
The skeleton copy is hidden and harmless, and because the directory pre-exists pam_mount never removes it (it only removes mountpoints it created).
Removing `makeHomeDir` would make `createMountPoints` the only creator and let `removeCreatedMountPoints` clean up, but it also changes behaviour on hosts without `nfs.homes` (en-t65-1 relies on it).
Leave it; note it in `services/AGENTS.md` as the ordering that matters.

**D5. Mount options: `nfsvers=4.2,hard,noatime,nosuid,nodev`, no `soft`.**
`hard` because home directories hold data users expect to be durable; a NAS stall then hangs that user's processes, which stay SIGKILL-able (fatal signals interrupt NFS waits since 2.6.25), satisfying the confinement requirement without risking torn writes.
`nosuid,nodev` because the export is writable by every directory user.
No `_netdev`, `nofail`, or `x-systemd.*`: those are fstab semantics and meaningless here.

**D6. Enforce boot independence in the aspect, not by convention.**
An `assertions` entry in `nfs.nix` rejects any `nfs.mounts[].local` in `[ "/" "/nix" "/var" "/etc" "/boot" "/home" "/root" "/persist" "/lab" ]`.
This is what turns the da-vcx-2 double definition from a latent bug into a build failure the task list fixes.

**D7. pam_mount is enabled for every PAM service; the gate is not.**
`security.pam.mount.enable = true` is global by design in NixOS (`pamMount` defaults to it per service), and pam_mount's own login counting assumes it sees every session type.
The gate only matters where a human arrives: `sshd` and `login`.
`sudo`/`su` to root never match a volume (root is uid 0) so nothing changes there.

**D8. Schema shape.**

```nix
host.nfs.homes = null | {
  server  : str;          # "10.32.10.1"
  remote  : str;          # export root, "/impulse/home"
  options : listOf str;   # default per D5
};
```

Colocated with `nfs.mounts`/`nfs.exports` in `modules/services/nfs.nix`; the aspect's `nixos` block gains a `lib.mkIf (host.nfs.homes != null)` branch for `security.pam.mount`, the two `rules.session` entries, `additionalSearchPaths = [ pkgs.nfs-utils ]`, and the `denTest` asserts the rendered `pam_mount.conf.xml` and `fileSystems`.

**D9. The NAS provisions homes itself, as one ZFS dataset per user, from a timer.**
Alternatives considered:

- _Client-side, in the login path_: a second `pam_exec` rule before `mount` that mounts the export root privately, creates the directory, and unmounts.
  Works only because the export is `no_root_squash`, puts NAS write logic on every node, slows first login, and cannot create datasets at all (that needs `zfs` on the NAS).
  Rejected.
- _Static `zfs.datasets` entries_: the existing helper, but SSSD users are not known at evaluation time, so it would need a hand-maintained list, which is the thing D2 exists to avoid.
  Rejected.
- _Plain directories instead of datasets_: a `mkdir` is simpler, but there is no per-user quota or snapshot boundary, and "up to 10 TB per user" only means something with a ceiling.
  The export already carries `crossmnt`, so child datasets cost nothing on the client side.
  Rejected.

Chosen shape: a oneshot `nfs-home-provisioning.service` driven by a timer (`OnBootSec=2min`, `OnUnitActiveSec=<interval>`, default `5min` to match SSSD's enumeration refresh), ordered after `zfs-import.target`, `zfs-datasets.service`, and `sssd.service`.
The script:

1. Lists candidates with `getent passwd`, keeping entries whose uid is ≥ 1000, whose name is not in the baked list of the NAS's own `isNormalUser` accounts, and whose home directory starts with `/home/` (a belt-and-braces guard so a directory user with a non-standard home never gets a dataset by accident).
   This is the same predicate as D2 and D3 expressed on the NAS.
2. For each candidate `u`, if `zfs list -H -o name <dataset>/<u>` succeeds, does nothing: create-only semantics mean an administrator's later `zfs set quota=…`, `chown`, or `chmod` survive every run.
3. Otherwise, if `<mountpoint>/<u>` exists as a plain directory, logs `nfs-home-provisioning: <path> is a directory, not a dataset — migrate by hand` and continues.
   `zfs create` over a non-empty directory succeeds but leaves the dataset unmounted, which would silently split the user's data; refusing is the only safe behaviour.
4. Otherwise `zfs create -o quota=<quota> -o acltype=posixacl -o xattr=sa <dataset>/<u>`, then `chown <uid>:<gid>`, `chmod 0700`, and `cp -a <skel>/. <mount>/` followed by a `chown -R` of the copied skeleton, mirroring `pam_mkhomedir` with umask 077.
   `acltype=posixacl` and `xattr=sa` match the `sync-tree` datasets so `setfacl` works the same everywhere.

The unit runs with `TimeoutStartSec=5min` and the timer never starts a second instance while one is active, so a suspended pool strands at most one `zfs` process.
Nothing is ever destroyed; cleanup of departed users is a human decision.

**D10. Provisioning schema shape.**

```nix
host.nfs.home-provisioning = null | {
  dataset  : str;   # "impulse/home" — parent dataset whose mountpoint is the export root
  quota    : str;   # default "1T"
  interval : str;   # systemd calendar/time span, default "5min"
  skel     : path;  # default /etc/skel
};
```

Colocated with `nfs.exports` in `modules/services/nfs.nix`, gated with `lib.mkIf (host.nfs.home-provisioning != null)`.
An assertion requires the parent dataset's mountpoint to be one of the host's `nfs.exports` paths, so provisioning cannot be pointed at something clients cannot reach.
da-gr75 sets `nfs.home-provisioning = { dataset = "impulse/home"; }` and takes every default.

## Risks / Trade-offs

- [A new authentik user logs in before the NAS has provisioned them] → the gate refuses with a journal line naming the missing home; the window is at most one interval (5 min) plus SSSD's own enumeration lag, and the retry succeeds with no administrator action.
- [da-gr75 is not deployable while `impulse` is unhealthy, so the provisioner may land after the client side] → the migration creates the current users' datasets by hand with the same `zfs create` flags; the provisioner finds them existing and does nothing when it finally runs.
- [A suspended pool turns the provisioner's `zfs` calls into unkillable D-state processes] → `TimeoutStartSec` bounds the unit, the timer does not overlap a running instance, and the unit is a oneshot that nothing else depends on, so the blast radius is one stuck process and a failed unit in `systemctl --failed`.
- [Existing plain-directory homes block dataset creation] → the provisioner refuses and logs rather than creating an unmounted dataset; the migration converts each directory to a dataset while that user is logged out (move aside, `zfs create`, `rsync -aAXH`, remove the copy).
- [Files written into local `/home/<user>` between the first-pass removal and this change are masked] → migration task lists any non-skeleton content under `/home/*` on da-vcx-1 and moves it aside before the deploy.
- [pam_mount counts sessions in `/run/pam_mount`; a crashed session can leave the count high and the mount in place] → benign (mount stays up until reboot); `removeCreatedMountPoints` is irrelevant because D4 pre-creates the directory.
- [Switching da-vcx-2 while its current `/home` NFS mount is wedged hangs activation] → use `just deploy da-vcx-2 -- --boot` and reboot, same as the da-vcx-1 first pass.
- [`disable_interactive` means pam_mount never prompts; NFS needs no password so this is fine, but any future crypt/FUSE volume would need a different service] → out of scope, noted.
- [Cloudflare-style "soft fail" expectations: a user may read the SSH "connection closed" as a network issue] → the sshd journal line and the `logger` message are the diagnostics; `nfs-homes:` prefix makes them greppable.

## Migration Plan

1. Land the aspect change with da-vcx-1's `nfs.homes` set, da-vcx-2 fixed (NFS `/home` removed, local btrfs `/home` kept), and da-gr75's `nfs.home-provisioning` set.
2. On da-gr75, convert each existing `/impulse/home/<user>` directory to a dataset while that user has no session on any node: `mv` it aside, `zfs create` with the D9 flags, `rsync -aAXH --numeric-ids` the contents in, verify, remove the copy.
   If da-gr75 cannot be deployed yet, this step is also where any missing current user gets a hand-made dataset with the same flags.
3. On da-vcx-1, inventory `/home/*` for non-skeleton content and move it aside (`/home/<user>.local-<date>`).
4. `just deploy da-vcx-1` (live switch is safe: no `/home` mount exists there any more), then test: `lab` SSH, directory-user SSH with the export up, directory-user SSH with the export blocked (RouterOS rule or `iptables` on the NAS), `kill -9` of a blocked process.
5. `just deploy da-vcx-2 -- --boot` and reboot; repeat the tests.
6. `just deploy da-gr75` as soon as its pool is deployable; run the provisioner once by hand (`systemctl start nfs-home-provisioning.service`) and verify it reports nothing to do for the migrated users, then create a throwaway authentik user and watch the dataset appear within one interval.
7. Rollback: set `nfs.homes = null` on the nodes and redeploy; pam_mount and the gate disappear, directory users fall back to local homes via `makeHomeDir`.
   Setting `nfs.home-provisioning = null` on the NAS stops the timer; datasets already created stay.

## Open Questions

- None.
  The `root_squash` question is resolved by D9: once the NAS provisions its own homes, no node needs root writes to the home export, and tightening the export becomes a self-contained hardening change later.
