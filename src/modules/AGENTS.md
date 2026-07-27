# src/modules — den aspects (the Nix heart of the repo)

Everything here is a **flake-parts module auto-imported by `import-tree`** —
every `*.nix` file, except inside `_`-prefixed directories (`_lib/`,
`_overlays/`), which are wired explicitly. There is no per-file `imports`
bookkeeping: dropping a file in the tree activates it.

This tree uses **den** (`github:denful/den`): feature-first aspects dispatched
to hosts/users by a context pipeline, NOT traditional per-host NixOS modules.
If you find yourself writing `options.rebellion.*`, `mkEnableOption`
boilerplate, or per-host `configuration.nix` — stop; that's the dead legacy
pattern.

> **den stamp**: behavior claims here (esp. Invariants) verified against
> `denful/den@99cc0c5`. den evolves fast and post-dates model knowledge —
> when `flake.lock` moves past this rev, re-verify the invariants and
> restamp. Ground truth is always the pinned source:
> `nix flake prefetch "github:denful/den/$(rev from flake.lock)" --json`
> prints its store path.

## Vocabulary

- **Aspect** — a feature card: per-class config + dependencies. Defined under
  the `rbn` namespace (`inputs.den.namespace "rbn" true` in `den.nix`).
- **Class keys** — where config lands: `nixos`, `darwin`, `homeManager`, and
  the virtual `os` (forwards to both nixos and darwin). Each key holds either
  an attrset or a module function.
- **`includes`** — composition: a list of aspect references, static attrsets,
  or parametric functions (`{ host, ... }: …`) dispatched by argument
  introspection.
- **`provides`** — named sub-aspects/variants scoped to an aspect, or plain
  data/functors other aspects consume.
- **`den.schema.host`** — typed options on the host submodule, readable as
  `host.*` inside aspects.
- **`den.default`** — the always-included aspect (global batteries: sops
  wiring, overlays, define-user, hostname).

## Naming: file path ↔ aspect path ↔ bracket path

The `._` attribute creates sub-aspects; `/` in angle brackets traverses both
`._` and `provides`:

| File                   | Aspect attr                   | Reference                     |
| ---------------------- | ----------------------------- | ----------------------------- |
| `programs/vcs/git.nix` | `rbn.programs._.vcs._.git`    | `<rbn/programs/vcs/git>`      |
| `suites/server.nix`    | `rbn.suite._.server`          | `<rbn/suite/server>`          |
| `system/networking/…`  | `rbn.system._.networking`     | `<rbn/system/networking>`     |
| variant via `provides` | `rbn.boot.provides.graphical` | `<rbn/system/boot/graphical>` |

One aspect per file; the file path mirrors the aspect path. kebab-case
everywhere. Files needing `<…>` brackets must destructure `__findFile` in
their module args.

## Anatomy of an aspect file

```nix
{ inputs, ... }:
{
  # Inputs are declared NEXT TO their consumer — flake-file regenerates
  # flake.nix from these. Never edit flake.nix by hand.
  flake-file.inputs.authentik-nix.url = "github:nix-community/authentik-nix";

  # Upstream module imports go through den.default for the relevant class.
  den.default.nixos.imports = [ inputs.authentik-nix.nixosModules.default ];

  # Schema colocated with the aspect that reads it (host.authentik.enable).

  rbn.services._.authentik = {
    nixos = { host, config, lib, pkgs, ... }: {
      # host.* (schema), lib.rbn.* (helpers) available here
    };
    provides.some-variant = { … };
  };
}
```

Parametric includes let an aspect adapt: `({ host, ... }: lib.optionalAttrs
(host.desktop or false) { includes = [ … ]; })`.

## Module args available inside class functions

`host` (the schema submodule), plus specialArgs injected by `defaults.nix`:
`datacenter`, `nodename`, `hostname` (parsed from the host name,
`da-vcx-1` → `da` / `vcx-1`), `format` (`linux`/`darwin`), `inputs`, `self`.
`lib` is extended with `lib.rbn` (see `_lib/AGENTS.md`) — helpers reach aspect
inner functions because the lib itself is extended, which specialArgs cannot
do.

## Routing table — where does a new X go?

| You're adding…                                        | Put it in       |
| ----------------------------------------------------- | --------------- |
| a daemon/system service (needs root, ports)           | `services/`     |
| an application/tool config (mostly HM)                | `programs/`     |
| platform plumbing (boot, networking, hw, nix)         | `system/`       |
| a login shell                                         | `shells/`       |
| a bundle of aspects enabled together                  | `suites/`       |
| cross-cutting host/user behavior (roles, persistence) | `classes/`      |
| a machine                                             | `hosts/<name>/` |
| a person/account                                      | `users/`        |
| palette/theming                                       | `theme/`        |
| a `lib.rbn` helper                                    | `_lib/`         |
| a package override or vendored package                | `_overlays/`    |
| sops material                                         | `secrets/`      |

Top-level single files are wiring, not aspects: `den.nix` (namespace +
systems), `schema.nix` (cross-cutting host options), `defaults.nix`
(instantiate override + `lib.rbn` extension), `overlays.nix` (overlay
discovery + `pkgs.contrib.*`), `inputs.nix`, `deploy.nix`, `mesh.nix`,
`facter.nix`.

## Invariants (hard-won — do not relearn)

- **Overlays must be global** (wired once in `overlays.nix` via
  `den.default`). Per-aspect `nixpkgs.overlays` causes infinite recursion.
- **A repo-defined parametric provider included from a user aspect reaches
  home-manager only, never the host.** Host-wide config must live in a system
  aspect included from the host side.
- **`host.primary-user`, not `host.user`** — `user` collides with den's
  pipeline context binding.
- **Unfree packages** are declared via den's unfree battery
  (`den.provides.unfree [ … ]`), not `allowUnfreePredicate` — the latter
  doesn't compose from within aspects.
- **One aspect owns each package and each dotfile.** Two aspects must never
  install the same package or write the same config file (PATH shadowing,
  activation conflicts). Within its owning aspect, a tool MAY deliberately
  exist at both system and HM level (system-wide default + user config) —
  the scope criteria live in `programs/AGENTS.md`.
- `den.schema.user.classes` defaults to `[ "homeManager" ]` (set in
  `den.nix`) — users get HM without opting in per-user.
