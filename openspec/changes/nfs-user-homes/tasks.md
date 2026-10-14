## 1. Baseline and inventory

- [ ] 1.1 Record the current evaluation baseline: `nix eval .#nixosConfigurations.da-vcx-1.config.system.build.toplevel.drvPath`, the same for `da-vcx-2` and `en-t65-1`, and `nix build .#checks.x86_64-linux.den-tests`; note which succeed (da-vcx-2 is expected to fail or warn on the double `/home` definition) so 7.x compares like for like; include `da-gr75` in the set
- [ ] 1.2 On da-gr75, list `/impulse/home/*` with numeric ownership (`ls -ln /impulse/home`) and `zfs list -r impulse/home`, and compare against `getent passwd` uids on da-vcx-1 for the current directory users; record which homes are plain directories versus datasets, any user missing a home, and any uid mismatch, for 8.1
- [ ] 1.3 On da-vcx-1, list `/home/*` and flag any directory holding more than the `/etc/skel` content (`diff -rq /etc/skel /home/<user>`); record the list for 8.3

## 2. Schema and boot-independence assertion (`modules/services/nfs.nix`)

- [ ] 2.1 Add `options.nfs.homes` (`nullOr (submodule { server; remote; options })`, default `null`, options default `[ "nfsvers=4.2" "hard" "noatime" "nosuid" "nodev" ]`) next to `nfs.mounts`; verify `nix eval .#nixosConfigurations.da-vcx-1.config.den-host.nfs.homes` (or the equivalent `host.*` accessor used in the repo) returns `null` before any host sets it
- [ ] 2.2 Add an `assertions` entry rejecting any `nfs.mounts[].local` in `/ /nix /var /etc /boot /home /root /persist /lab`, message naming the path and "nas-attachment: NAS storage is never a boot or activation dependency"; verify by evaluating da-vcx-2 unchanged and seeing the assertion fire on `/home`

## 3. pam_mount volume and login gate (`modules/services/nfs.nix`)

- [ ] 3.1 Under `lib.mkIf (host.nfs.homes != null)`, set `security.pam.mount = { enable = true; createMountPoints = true; removeCreatedMountPoints = true; additionalSearchPaths = [ pkgs.nfs-utils ]; }`; verify the built system's `/etc/security/pam_mount.conf.xml` contains a `<path>` including `nfs-utils` (`nix build … && cat result/etc/security/pam_mount.conf.xml`)
- [ ] 3.2 Generate the single `extraVolumes` entry in extended user-control form: `fstype="nfs"`, `server`, `path="<remote>/%(USER)"`, `mountpoint="/home/%(USER)"`, `options` joined with commas, body `<and><uid>1000-4294967294</uid>` plus one `<not><user>NAME</user></not>` per `isNormalUser` account in `config.users.users` `</and>`; verify the rendered XML lists `lab` and no simple `user=`/`uid=` attributes, and that `xmllint --noout` (or `pkgs.libxml2`) accepts the file
- [ ] 3.3 Write the gate script with `pkgs.writeShellApplication` (runtime inputs: `util-linux` for `mountpoint`, `glibc`/`getent`, `logger`): exit 0 unless `PAM_TYPE=open_session`; exit 0 if `PAM_USER` is in the baked local-user list or `getent passwd` reports uid < 1000; otherwise `mountpoint -q /home/$PAM_USER` or log `nfs-homes: refusing <user>: /home/<user> is not mounted` and exit 1; verify by running it by hand with `PAM_TYPE=open_session PAM_USER=lab` (exit 0) and `PAM_USER=<fake uid 5000 user>` with no mount (exit 1, journal line present)
- [ ] 3.4 Attach the gate to `sshd` and `login` as `security.pam.services.<svc>.rules.session.nfs-homes-gate = { control = "required"; modulePath = "${pkgs.pam}/lib/security/pam_exec.so"; order = 11350; settings.quiet = true; args = [ "<script>" ]; }`; verify the generated `/etc/pam.d/sshd` shows `pam_mount.so` then `pam_exec.so … nfs-homes-gate` then `pam_ldap`/`pam_sss`, and `/etc/pam.d/sudo` has no `pam_exec` gate line
- [ ] 3.5 Add a `denTest` beside the aspect (`flake.tests.services.nfs`): a synthetic host with `nfs.homes` set and users `lab` + `extra` declared; assert `fileSystems` has no `/home` key, the rendered volume excludes both declared users, and a second synthetic host without `nfs.homes` renders no pam_mount config; verify `nix build .#checks.x86_64-linux.den-tests` passes

## 4. NAS-side provisioning (`modules/services/nfs.nix`, server side)

- [ ] 4.1 Add `options.nfs.home-provisioning` (`nullOr (submodule { dataset; quota default "1T"; interval default "5min"; skel default /etc/skel })`, default `null`) next to `nfs.exports`, plus an assertion that the parent dataset's mountpoint equals one of the host's `nfs.exports[].path`; verify evaluating a synthetic host with `dataset = "impulse/home"` and no matching export fails with that message
- [ ] 4.2 Write the provisioning script with `pkgs.writeShellApplication` (runtime inputs: `zfs`, `glibc` for `getent`, `coreutils`, `util-linux` for `logger`): candidates are `getent passwd` entries with uid ≥ 1000, name not in the baked `isNormalUser` list, home under `/home/`; for each, skip if `zfs list -H -o name <dataset>/<user>` succeeds; log and skip if `<mountpoint>/<user>` is a plain directory; else `zfs create -o quota=<quota> -o acltype=posixacl -o xattr=sa`, `chown uid:gid`, `chmod 0700`, `cp -a <skel>/. <mount>/` and `chown -R uid:gid` of the copied files; verify by running it on a scratch pool (`truncate -s 1G` file, `zpool create scratch`) with a fake passwd entry via `getent`-compatible stub or by pointing `dataset` at the scratch pool: dataset created with the right properties, second run is a no-op, a pre-made plain directory is skipped with a log line
- [ ] 4.3 Add `systemd.services.nfs-home-provisioning` (oneshot, `TimeoutStartSec=5min`, `after`/`wants` `zfs-import.target`, `zfs-datasets.service`, `sssd.service`) and `systemd.timers.nfs-home-provisioning` (`OnBootSec=2min`, `OnUnitActiveSec=<interval>`, `wantedBy = [ "timers.target" ]`); verify the built da-gr75 system has both units, the timer references the service, and `systemctl cat` output shows the ordering
- [ ] 4.4 Extend the `denTest` from 3.5: a synthetic NAS host with `nfs.exports = [ { path = "/impulse/home"; } ]` and `nfs.home-provisioning.dataset = "impulse/home"` renders the timer, and a host without the knob renders no `nfs-home-provisioning` unit; verify `nix build .#checks.x86_64-linux.den-tests` passes

## 5. Host data

- [ ] 5.1 `modules/hosts/da-vcx-1/da-vcx-1.nix`: add `nfs.homes = { server = "10.32.10.1"; remote = "/impulse/home"; }`; verify `nix build .#nixosConfigurations.da-vcx-1.config.system.build.toplevel` succeeds and `result/etc/fstab` contains `/srv/media` but no `/home`
- [ ] 5.2 `modules/hosts/da-vcx-2/da-vcx-2.nix`: remove the `/home` entry from `nfs.mounts` (leaving `nfs.mounts = [ ]` or dropping the attribute) and add the same `nfs.homes`; keep the btrfs `fileSystems."/home"` in `_hardware.nix`; verify the host now evaluates, `result/etc/fstab` has exactly one `/home` line and it is btrfs
- [ ] 5.3 `modules/hosts/da-gr75/da-gr75.nix`: add `nfs.home-provisioning = { dataset = "impulse/home"; }`; verify `nix build .#nixosConfigurations.da-gr75.config.system.build.toplevel` succeeds and `result/etc/systemd/system/timers.target.wants/` links `nfs-home-provisioning.timer`
- [ ] 5.4 Confirm en-t65-1 is untouched: build it and verify `result/etc/pam.d/sshd` has no `pam_mount` or `nfs-homes-gate` lines, `/etc/security/pam_mount.conf.xml` is absent, and no `nfs-home-provisioning` unit exists

## 6. Rules and comment sweep

- [ ] 6.1 Lift the design facts that matter at edit time into `modules/services/AGENTS.md`: the boot-independence list and why, "per-user homes are session mounts, never fstab", `makeHomeDir` (10700) runs before `mount` (11300) and the gate sits at 11350, pam_mount cannot deny so the gate exists, the extended-vs-simple user-control rule, and the provisioner's create-only and skip-plain-directory rules with why; verify the file's `paths:` frontmatter still covers `modules/services/**` and no duplicate of this text exists in `nfs.nix` comments
- [ ] 6.2 Run `nix fmt` / `jj fix` and `prek run` (or the installed pre-commit); verify no formatting diff remains and all hooks pass

## 7. Evaluation gates

- [ ] 7.1 Re-run every command from 1.1 and verify da-vcx-1, da-vcx-2, da-gr75, en-t65-1 all evaluate and `den-tests` passes; en-t65-1's `drvPath` must be unchanged from 1.1
- [ ] 7.2 `nix flake check`; verify it passes (or that the only failures are pre-existing ones recorded in 1.1)

## 8. NAS preparation and local-home migration

- [ ] 8.1 On da-gr75, for each current directory user from 1.2, while that user has no session on any da node: if their home is a plain directory, `mv /impulse/home/<user> /impulse/home/<user>.migrating`, `zfs create -o quota=1T -o acltype=posixacl -o xattr=sa impulse/home/<user>`, `chown <uid>:<gid>` and `chmod 0700` the mountpoint, `rsync -aAXH --numeric-ids /impulse/home/<user>.migrating/ /impulse/home/<user>/`, compare with `rsync -aAXHn --numeric-ids --delete` (expect no output), then remove the copy; if they have no home at all, create the dataset the same way and copy `/etc/skel`; verify `zfs list -r impulse/home` lists one dataset per current directory user with `quota 1T` and `ls -ln /impulse/home` shows the uid `getent passwd` reports on da-vcx-1
- [ ] 8.2 On da-gr75, confirm the export is live for the lab CIDR: `exportfs -v | rg /impulse/home` and from da-vcx-1 `showmount -e 10.32.10.1` lists it; verify a manual `mount -t nfs -o nfsvers=4.2 10.32.10.1:/impulse/home/<user> /mnt` as root on da-vcx-1 succeeds, `findmnt /mnt` shows the per-user dataset (not the parent) via `crossmnt`, and it is unmounted again
- [ ] 8.3 On da-vcx-1, move aside every directory flagged in 1.3 to `/home/<user>.local-$(date +%F)`; verify `/home/<user>` is absent or skeleton-only for each flagged user

## 9. Deploy and verify da-vcx-1 (no `/home` mount exists there, live switch is safe)

- [ ] 9.1 `just deploy da-vcx-1`; verify the activation completes with no failed units (`systemctl --failed` empty) and `kubectl get node da-vcx-1` stays Ready throughout
- [ ] 9.2 `lab` SSH login; verify it lands in `/lab` and `findmnt /home/lab` is empty
- [ ] 9.3 Directory-user SSH login with the export reachable; verify `findmnt -T ~` shows `10.32.10.1:/impulse/home/<user>` type `nfs4` with `hard,nosuid,nodev`, `df -h ~` reports the 1 TB dataset rather than the whole pool, a file created there is visible on da-gr75 under `/impulse/home/<user>`, and `journalctl -t nfs-homes` is empty
- [ ] 9.4 Close that user's last session; verify `findmnt /home/<user>` on da-vcx-1 is empty within a few seconds
- [ ] 9.5 Block the export (on da-gr75: `iptables -I INPUT -s 10.32.11.1 -p tcp --dport 2049 -j DROP`, or the RouterOS equivalent) and attempt the directory-user SSH login; verify the connection closes after authentication, `journalctl -u sshd` shows `pam_open_session` failing, `journalctl -t nfs-homes` shows the refusal with the user name, and a concurrent `lab` login succeeds; remove the block afterwards
- [ ] 9.6 With the export reachable, open a directory-user session, start `sleep 1000 > ~/x`, block the export as in 9.5, and verify `kill -9` terminates the process, `lab` can still log in, the node stays Ready, and `systemctl --failed` is empty; remove the block
- [ ] 9.7 Attempt login as a directory user with no home on the export (temporarily `zfs rename` one user's dataset aside); verify refusal with the missing-home reason in `journalctl -t nfs-homes`; rename it back and verify the next login succeeds

## 10. Deploy and verify da-vcx-2

- [ ] 10.1 If `findmnt /home` on da-vcx-2 shows a wedged or stale NFS mount, deploy with `just deploy da-vcx-2 -- --boot` and reboot; otherwise `just deploy da-vcx-2`; verify after boot that `/home` is the local btrfs subvolume (`findmnt /home` shows `btrfs`) and `systemctl --failed` is empty
- [ ] 10.2 Repeat 9.2, 9.3, and 9.5 on da-vcx-2; verify the same outcomes and that a file created in the directory user's home on da-vcx-1 is visible from da-vcx-2

## 11. Deploy and verify da-gr75 (when its pool is deployable; see the HBA notes)

- [ ] 11.1 `just deploy da-gr75` (or `-- --boot` plus reboot if any unit stop could touch the pool); verify `systemctl --failed` is empty, `systemctl list-timers` shows `nfs-home-provisioning.timer`, and `/impulse/home` is still exported (`exportfs -v`)
- [ ] 11.2 `systemctl start nfs-home-provisioning.service` by hand; verify `journalctl -u nfs-home-provisioning` reports no creations for the users migrated in 8.1, `zfs list -r impulse/home` is unchanged, and the unit exits 0
- [ ] 11.3 Create a throwaway user in authentik, wait for SSSD on da-gr75 to enumerate it (`getent passwd <user>`), then wait one interval; verify `zfs list impulse/home/<user>` exists with `quota 1T`, `acltype posixacl`, `xattr sa`, mountpoint owned by the new uid, mode `0700`, skeleton files present; then log in as that user on da-vcx-1 and verify the home mounts without any manual step
- [ ] 11.4 `zfs set quota=2T impulse/home/<throwaway>` and run the service again; verify the quota stays `2T`; then remove the throwaway user from authentik, run the service once more, and verify the dataset still exists; finally `zfs destroy` it by hand

## 12. Close out

- [ ] 12.1 Commit in Conventional Commits form (`feat(nix/services/nfs): per-user NAS homes for directory users with a login gate`, `feat(nix/services/nfs): provision per-user home datasets on the NAS`, plus a separate `fix(nix/hosts/da-vcx-2): drop boot-time NFS /home` if kept as separate commits); verify `jj log` shows the commits and `jj diff -r @` is empty
- [ ] 12.2 Append the follow-ups to `openspec/` as new changes or notes, not to this one: `/srv/media` hostPath to per-pod NFS volumes, GlusterFS vs FS-Cache on the new 6 TB node drives, `root_squash` on the home export now that no node needs root writes there; verify each has a one-line pointer so none is lost
