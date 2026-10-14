## Why

da-gr75 is the datacenter's NAS, and the point of a NAS is that any account on any da compute node sees the same multi-terabyte home without every node carrying a copy of the array.
Until 2026-10-01 that was done by mounting the export _as_ `/home` on each node at boot, and the HBA failure on da-gr75 showed what that costs: a dead export left `/home` as a wedged automount, so every `ProtectHome` daemon failed to start, the NixOS users activation step failed on `install -d /home`, deploy-rs rolled back, and the node could not be redeployed until the NAS was healthy.
The blanket mount has since been removed from da-vcx-1 (deployed with `--boot` and rebooted); da-vcx-2 still declares it.
This change puts the NAS-backed homes back in a form that cannot take a node, its activation, or its services down when da-gr75 is unavailable.

## What Changes

- **New host knob `nfs.homes`** on the NFS service aspect: a server, an export root, and mount options.
  When set, the host mounts `<server>:<export>/<user>` at `/home/<user>` for the duration of each login session via `pam_mount`, and unmounts on the last logout.
  Nothing is added to `fileSystems`, so nothing about `/home` appears in fstab, in the boot transaction, or in the activation script.
- **Only directory users get a NAS home.**
  The volume selector is derived from the evaluated configuration: it matches every account that is not declared in `users.users` and is not a system account (uid below 1000).
  On the da nodes that is exactly the SSSD/LDAP population from authentik; `lab` (home `/lab`) and `root` never match and keep local homes.
- **A login gate.**
  `pam_mount` reports success to PAM even when a mount fails (verified in its source), so a new `pam_exec` session rule, ordered immediately after `mount` and marked `required`, fails the session for any matching user whose `/home/<user>` is not a live mountpoint.
  With the export unreachable, a directory user's SSH or console login is refused with a logged reason instead of landing in an empty local directory that a later mount would mask.
  Local accounts are unaffected by the gate.
- **da-vcx-2 loses its boot-time `/home` NFS mount** (and the resulting conflict with the local btrfs `/home` subvolume in its hardware file) and gains `nfs.homes` like da-vcx-1.
  da-vcx-1 gains `nfs.homes`; its `/srv/media` mount is untouched by this change.
- **The NAS provisions the homes it serves.**
  A new server-side knob `nfs.home-provisioning` on da-gr75 runs a timer every five minutes (SSSD's enumeration refresh interval) that lists directory users and, for each one without a home, creates a ZFS dataset `impulse/home/<user>` with a 1 TB quota, POSIX ACLs enabled, ownership from the user's uid and primary gid, mode `0700`, and the skeleton copied once.
  It never destroys a dataset and never re-applies quota, ownership, or mode to one that already exists, so per-user overrides made by hand survive.
  This is the NAS-side equivalent of what `pam_mkhomedir` does locally, and it is what makes the login gate self-healing: a newly created authentik user is refused for at most one interval, then admitted.
- **Boot independence becomes a stated invariant** of the NFS aspect: a host may not place `/home`, `/root`, `/var`, `/nix`, or its persistence root on an NFS mount, and the aspect asserts it at evaluation time.
- **da only.**
  en-t65-1 is a single node with no storage node; it has no `nfs.homes` and keeps local homes.

## Capabilities

### New Capabilities

- `nas-attachment`: how da compute nodes attach storage served by the datacenter NAS (da-gr75) without making it a boot or activation dependency.
  This change covers the invariant (nothing the OS needs lives on the NAS), the first attachment kind, per-user NFS homes for directory users with the login gate, and the NAS-side provisioning of those homes.
  Later changes are expected to modify it for per-pod media volumes and read caching.

### Modified Capabilities

- None.
  `bootstrap`, `repo-layout`, `package-scope`, and `hubitat-drivers` do not describe host storage.

## Impact

- **Nix modules**: `modules/services/nfs.nix` (new `nfs.homes` and `nfs.home-provisioning` schema, pam_mount wiring, gate rule, provisioning timer, boot-independence assertion), `modules/hosts/da-vcx-1/da-vcx-1.nix`, `modules/hosts/da-vcx-2/da-vcx-2.nix`, and `modules/hosts/da-gr75/da-gr75.nix` (host data), `modules/services/ldap.nix` unchanged in behavior but its `makeHomeDir` ordering relative to `mount` is now load-bearing and is documented.
  A `denTest` covers the volume selector and the absence of any `/home` entry in `fileSystems`.
- **Live hosts**: da-vcx-1 is already free of the blanket mount; this is additive there.
  da-vcx-2 removes a mount and must be switched with `deploy --boot` and a reboot if its export is unreachable at the time, since stopping a wedged hard mount in place hangs activation.
- **Users**: directory users logging into da nodes between the first-pass removal and this change land in a local empty `/home/<user>`; anything written there becomes invisible once the per-user mount is active.
  The migration task copies such directories aside before enabling the mount.
- **da-gr75**: gains the provisioning timer and keeps exporting `/impulse/home` to the lab CIDR unchanged.
  The homes there today are plain directories; each becomes a per-user dataset as part of the migration, while that user is logged out.
  da-gr75 cannot currently be deployed while its pool is unhealthy, so the provisioner lands on its next deployable generation and the migration carries a manual `zfs create` fallback until then.
- **Not touched**: the `/srv/media` hostPath on da-vcx-1 and the media pods (follow-up: per-pod NFS volumes), FS-Cache or any local caching tier on the new 6 TB drives (follow-up: GlusterFS vs FS-Cache evaluation), the export options themselves (follow-up: `root_squash` once nothing on the nodes needs root writes), en, Samba/Time Machine targets on the NAS, sssd configuration.
