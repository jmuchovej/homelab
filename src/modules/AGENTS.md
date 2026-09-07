---
paths:
  - "src/modules/**"
---

# src/modules — layout of the den tree

Everything here is a **flake-parts module auto-imported by `import-tree`**:
every `*.nix` file, except paths with a `_` prefix (`_lib/`, `_overlays/`,
`ai-tools/_lib.nix`), which are wired explicitly by whoever owns them. There
is no per-file `imports` bookkeeping — dropping a file in the tree activates
it, and so does a stray one.

How aspects are _written_ (class keys, includes, provides, schema, policies,
invariants) is `den-style.md`. This file is only about **where things go**.

## Routing table — where does a new X go?

| You're adding…                                        | Put it in                           |
| ----------------------------------------------------- | ----------------------------------- |
| a daemon/system service (needs root, ports)           | `services/`                         |
| an application/tool config (mostly HM)                | `programs/`                         |
| platform plumbing (boot, networking, hw, nix)         | `system/`                           |
| a login shell                                         | `shells/`                           |
| a bundle of aspects enabled together                  | `suites.nix`                        |
| a den policy, class alias, or schema-driven behaviour | `classes/`                          |
| a machine                                             | `hosts/<name>/`                     |
| a person/account                                      | `users/`                            |
| palette/theming                                       | `theme/`                            |
| a `lib.rbn` helper                                    | `_lib/`                             |
| a package override or vendored package                | `_overlays/`                        |
| sops material                                         | top-level `secrets/`, not this tree |

Each directory's own `AGENTS.md` carries its conventions: the shape of a
service, the two halves of a host file, user-file anatomy, variant selection in
`system/`.

## Top-level files are wiring, not aspects

`den.nix` (namespace + systems + `__findFile` + `denTest`), `schema.nix`
(cross-cutting host options), `defaults.nix` (`instantiate` overrides that
inject `lib.rbn` and host specialArgs), `overlays.nix` (overlay discovery +
`pkgs.contrib.*`), `inputs.nix`, `deploy.nix`, `facter.nix`. `suites.nix` is
the one top-level _aspect_ file: every `rbn.suite._.<name>` lives there.

`classes/` is not a directory of aspects either. It holds den-level
customisation: class aliases and routes (`aliases.nix`), named policies
(`policies.nix`), and behaviours keyed off host/user schema rather than
included by name (`roles.nix`, `persistence.nix`, `desktop.nix`).

## Repo design decisions (not den behaviour)

- **No "primary user" host option.** Config keyed on the primary account
  (doas, nix-homebrew owner, dock, macOS defaults, trusted-users) is written
  as `{ user, ... }` class content and included from that user's aspect;
  `den.batteries.primary-user` sits alongside it. Whichever of a host's users
  includes them is primary — lab on servers, john on da-n1x.
- **One aspect owns each package and each dotfile.** Two aspects must never
  install the same package or write the same config file (PATH shadowing,
  activation conflicts). Within its owning aspect, a tool MAY deliberately
  exist at both system and HM level (system-wide default + user config) —
  the scope criteria live in `programs/AGENTS.md`.

## Suites (`suites.nix`)

`rbn.suite._.<name>` — curated `includes` lists with minimal owned config.
Suites are the only place aspects get bundled; hosts and users include suites
plus à-la-carte extras.

Hierarchy: `common` (universal floor: system base + CLI tools + shells) ←
`server` (adds `common` + `development` + hardening + the `lab` user) and
`desktop` (adds `common` + GUI floor). `development` is Nix-tooling extras.

A suite may own small config directly (e.g. `server` defines the `lab` user
and documentation trimming) — but the moment owned config grows a "why", it
should become its own aspect and be included instead.
