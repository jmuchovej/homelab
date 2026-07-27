# hosts/ — machines

One directory per host: `hosts/<name>/<name>.nix` + `facter.json` (hardware
report, exposed to users via the host's `provides.to-users`). Host names are
`<datacenter>-<node>` (`da-vcx-1`) — `datacenter`/`nodename` are parsed from
the name by the schema, so the name is load-bearing.

Each host file has two halves:

1. **`den.hosts.<system>.<name> = { … }`** — schema data: per-service knobs
   (`authentik.enable`, `s3.buckets`, `nfs.mounts`, `persistence.*`, model
   lists…). This is _data_, read by service aspects as `host.*`.
2. **`den.aspects.<name>`** — behavior: `includes` (a suite + hardware leaf
   aspects + selected networking backends + services) and a small `nixos`
   block for host-anchored facts (`networking.hostId`, `boot.zfs.extraPools`,
   `system.stateVersion` — never bump stateVersion casually).

Commented-out entries in `includes` are **deliberate toggles** (services
paused or awaiting migration) — do not "clean them up", and do not enable
them without cause. User membership on a host is declared from the user's
file, not here (`users/AGENTS.md`).
