---
paths:
  - "src/modules/**"
---

# den — how this repo uses the framework

den (`github:denful/den`) is an aspect-oriented, context-driven layer above
NixOS / nix-darwin / Home Manager. Configuration is written as feature-first
**aspects** and dispatched to hosts and users by a context pipeline — not as
per-host module lists. If you find yourself writing `options.rebellion.*`,
`mkEnableOption` boilerplate, a `cfg.enable` gate, or a per-host
`configuration.nix`, stop: that is the dead pre-den pattern.

> **den stamp**: behaviour claims here (esp. Invariants) were verified against
> `denful/den@99cc0c5`. den evolves fast and post-dates model knowledge — when
> `flake.lock` moves past this rev, re-verify and restamp (the `flake-brief`
> skill does the diffing). Ground truth is the pinned source:
> `nix flake prefetch "github:denful/den/<rev from flake.lock>" --json` prints
> its store path; `docs/src/content/docs/` inside it is the manual.

## Vocabulary

- **Aspect** — the unit of content: an attrset of class keys, `includes`,
  `provides`, and nested sub-aspects. All repo aspects live under the `rbn`
  namespace (`inputs.den.namespace "rbn" true` in `den.nix`).
- **Class keys** — where config lands. Each holds an attrset or a module
  function `{ pkgs, host, ... }: { … }`. See the table below.
- **`includes`** — composition: a list of aspect references (`<rbn/…>`),
  inline attrsets, batteries, policies, or parametric functions
  (`{ host, ... }: …`) that den dispatches by argument introspection.
- **`provides` / `_`** — named sub-aspects on any aspect (`_` is the alias
  for `provides`). Used for variants (`boot.provides.graphical`) and for plain
  data other aspects read (`provides.to-users`).
- **`den.schema.host` / `den.schema.user`** — typed options on the host/user
  submodule, readable as `host.*` / `user.*` inside aspects. Declared
  colocated with the aspect that reads them; cross-cutting ones live in
  `schema.nix`.
- **`den.default`** — the always-included aspect. Global batteries, upstream
  module imports, sops wiring, and overlays hang off it.
- **Batteries** — den-shipped aspects/functors. In use here:
  `den.batteries.unfree`, `insecure`, `forward`, `hostname`, `define-user`,
  `primary-user`, `user-shell`.
- **Policies** — named, context-driven include rules (`den.lib.policy.*`).
  Repo-defined ones are exposed as the `rbn-policies` module arg.

## Class keys

| Key                                            | Lands in                                      | Defined by                      |
| ---------------------------------------------- | --------------------------------------------- | ------------------------------- |
| `nixos`, `darwin`, `homeManager`               | native                                        | den                             |
| `os`                                           | nixos **and** darwin                          | den `os-class` battery          |
| `macos`                                        | darwin                                        | `classes/aliases.nix` (route)   |
| `hm`                                           | homeManager                                   | `classes/aliases.nix` (route)   |
| `hm-linux`, `hm-macos`, `hm-arm64`, `hm-amd64` | homeManager, guarded on `stdenv.hostPlatform` | `classes/aliases.nix` (forward) |

Prefer the short aliases (`hm` over `homeManager`, `macos` over `darwin`).
**Exception**: the forwarded `hm*` keys accept plain config only. A module that
needs `imports`, `options`, or an explicit `config` key must use the native
`homeManager` key — the NOTE in `classes/aliases.nix` explains why.

## Naming: file path ↔ aspect path ↔ bracket path

`._` creates sub-aspects; `/` inside angle brackets traverses both `._` and
`provides`:

| File                   | Aspect attr                            | Reference                     |
| ---------------------- | -------------------------------------- | ----------------------------- |
| `programs/vcs/git.nix` | `rbn.programs._.vcs._.git`             | `<rbn/programs/vcs/git>`      |
| `suites/server.nix`    | `rbn.suite._.server`                   | `<rbn/suite/server>`          |
| variant via `provides` | `rbn.system._.boot.provides.graphical` | `<rbn/system/boot/graphical>` |

The file path mirrors the aspect path. A file normally holds one aspect, but
sibling sub-aspects may share a file when they share a computed `let`
(`ai-tools/ai-tools.nix` defines `_.mcp` and `_.skills` over one skills set) or
are individually tiny (`suites.nix` holds every `rbn.suite._.<name>`). Bracket
references are unaffected either way. A file that uses `<…>` brackets must
destructure `__findFile` in its flake-module args.

## Anatomy of an aspect file

```nix
{ inputs, __findFile, rbn-policies, ... }:
{
  # Inputs are declared NEXT TO their consumer — flake-file regenerates
  # flake.nix from these. Never edit flake.nix by hand.
  flake-file.inputs.authentik-nix.url = "github:nix-community/authentik-nix";

  # Upstream module imports go through den.default for the relevant class.
  den.default.nixos.imports = [ inputs.authentik-nix.nixosModules.default ];

  # Schema colocated with the aspect that reads it (host.authentik.enable).
  den.schema.host.options.authentik.enable = lib.mkEnableOption "…";

  rbn.services._.authentik = {
    includes = [
      <rbn/services/postgres>
      (rbn-policies.when-desktop "authentik" <rbn/services/authentik/ui>)
    ];
    nixos = { host, config, lib, pkgs, ... }: {
      # host.* (schema), lib.rbn.* (helpers) available here
    };
    provides.ui = { … };
  };
}
```

## Two argument sets — don't confuse them

- **Flake-module args** (the file's outer function): `inputs`, `den`, `lib`,
  `__findFile`, `rbn-policies`, `denTest`. This is flake-parts scope.
- **Class-function args** (inside `nixos = { … }: …`): the usual module args
  plus `host` (schema submodule) and the specialArgs injected by
  `defaults.nix`: `datacenter`, `nodename`, `hostname` (`da-vcx-1` → `da` /
  `vcx-1`), `format` (`linux`/`darwin`), `inputs`, `self`. `lib` is extended
  with `lib.rbn` (`_lib/AGENTS.md`) via `lib.extend`, which is why it reaches
  aspect inner functions when specialArgs cannot. Standalone homes
  (`den.homes`) get the extended lib through a separate
  `den.schema.home.instantiate` override; `osConfig` is **not** wired for them.

## Conditional inclusion

- Gate on host metadata with a **named policy**, not an anonymous parametric
  include: `(rbn-policies.when-desktop "claude" <rbn/…/desktop>)`. Named
  policies have identity (targetable by `excludes`, readable in debug output)
  and keep the injected aspect non-parametric so den's dedup still collapses
  it. Rationale and the naming constraint live in `classes/policies.nix`.
- Anonymous `({ host, ... }: lib.optionalAttrs (host.desktop or false) { … })`
  is acceptable in a user file for one-off selections. Always write
  `host.desktop or false`: standalone homes resolve against a null host.

## Invariants (hard-won — do not relearn)

- **Overlays must be global**, wired once in `overlays.nix` via `den.default`.
  Per-aspect `nixpkgs.overlays` causes infinite recursion.
- **den does not honor `imports` on an aspect.** Upstream modules are
  imported at class level: `den.default.<class>.imports = [ … ]`.
- **A parametric provider included from a user aspect reaches home-manager
  only, never the host.** Host-wide config must be included from the host
  side.
- **Unfree / insecure packages** go through the batteries
  (`den.batteries.unfree [ "claude-code" ]`), never `allowUnfreePredicate` —
  the predicate does not compose from inside aspects.
- `den.schema.user.classes` defaults to `[ "homeManager" ]` (`den.nix`), so
  users get HM without opting in.
- `denTest` unit tests are co-located with the code they cover
  (`flake.tests.<suite>`, see `classes/aliases.nix`). They can assert the
  _negative_ case — content correctly not applied — which a real-host eval
  cannot do cheaply.
