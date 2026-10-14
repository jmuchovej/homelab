---
paths:
  - "modules/system/**"
---

# system/ — platform plumbing

Aspects under `rbn.system._.<name>`: boot, networking, hardware, nix itself, fonts, homebrew, dock, environment, filesystems, security, time, virtualization.
These are infrastructure — selected by suites and hosts, not by users.

## The variant-selection pattern

When a concern has interchangeable backends, the base aspect carries shared config and each backend is a sub-aspect; the **host** picks exactly one:

- `networking/` → base + `dns/{dnsmasq,resolved}` + `manager/{networkd,networkmanager}`; host includes e.g. `<rbn/system/networking/dns/dnsmasq>`.
- `boot` → base + `<rbn/system/boot/graphical>`.
- `hardware/` → leaf aspects per component: `cpu/intel`, `gpu/nvidia`, `storage/{ssd,btrfs,zfs,zfs/managed}` — hosts compose what matches their metal.

Small always-on tweaks ride as `provides` on the base aspect (`networking.provides.{static,wol}`).

## Darwin specifics (carried from the pre-den tree — still true)

- `defaults`-based settings often need a process restart to apply: activation scripts `killall Dock` / `killall SystemUIServer` after writing dock/menubar defaults.
- Finder uses opaque four-char codes: view styles `icnv`/`Nlsv`/`clmv`/`Flwv` (`FXPreferredViewStyle`), search scopes `SCev`/`SCcf`/`SCsp` (`FXDefaultSearchScope`).
- Homebrew prefix is architecture-dependent: `/opt/homebrew` (Apple Silicon) vs `/usr/local` (Intel) — guard path-dependent config on `pkgs.stdenv.hostPlatform.isAarch64`.
- `duti` sets default handlers declaratively from activation scripts (e.g. `duti -s org.mozilla.firefox public.html all`).

## Dock

`dock.nix` owns three things: `den.reservedKeys = [ "dock" ]`, the `user.dock` schema, and the darwin builder.
Reserving the key is what makes `dock.{key,source,path}` on a program aspect plain data — den's `aspectKeyType` passes a reserved key through untouched, where any other freeform key is wrapped as class content and unreadable from the tree.
The builder collects `dock` from every node of `user.aspects`, resolves each entry's `source` to a directory, and emits `system.defaults.dock.persistent-apps`:

| `source`      | directory                                                                       |
| ------------- | ------------------------------------------------------------------------------- |
| `hm`          | `~/Applications/Home Manager Apps`                                              |
| `brew`        | `~/Applications` — `homebrew.caskArgs.appdir` in `homebrew.nix` puts casks here |
| `user-apps`   | `~/Applications`                                                                |
| `root-apps`   | `/Applications`                                                                 |
| `nix-apps`    | `/Applications/Nix Apps`                                                        |
| `system-apps` | `/System/Applications`                                                          |

`user.aspects` is read inside the `macos` class body, the one place den guarantees the resolved tree is frozen; deciding `includes` from it recurses.
Linux desktops are not handled yet — `source` is the hook for that: same keys, a per-platform directory map.
What programs declare and how users lay groups out are `programs/AGENTS.md` and `users/AGENTS.md`.
The builder's unit test (`flake.tests.system.dock`) shares the schema and aspect through a `let` instead of importing the file, for the same reason `classes/aliases.nix` does.

## Fonts

Fonts are a system concern (`system/fonts`), consumed by both theming and individual apps — don't declare fonts per-program.
