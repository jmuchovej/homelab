# system/ — platform plumbing

Aspects under `rbn.system._.<name>`: boot, networking, hardware, nix itself,
fonts, homebrew, dock, environment, filesystems, security, time,
virtualization. These are infrastructure — selected by suites and hosts, not
by users.

## The variant-selection pattern

When a concern has interchangeable backends, the base aspect carries shared
config and each backend is a sub-aspect; the **host** picks exactly one:

- `networking/` → base + `dns/{dnsmasq,resolved}` +
  `manager/{networkd,networkmanager}`; host includes e.g.
  `<rbn/system/networking/dns/dnsmasq>`.
- `boot` → base + `<rbn/system/boot/graphical>`.
- `hardware/` → leaf aspects per component: `cpu/intel`, `gpu/nvidia`,
  `storage/{ssd,btrfs,zfs,zfs/managed}` — hosts compose what matches their
  metal.

Small always-on tweaks ride as `provides` on the base aspect
(`networking.provides.{static,wol}`).

## Darwin specifics (carried from the pre-den tree — still true)

- `defaults`-based settings often need a process restart to apply: activation
  scripts `killall Dock` / `killall SystemUIServer` after writing dock/menubar
  defaults.
- Finder uses opaque four-char codes: view styles `icnv`/`Nlsv`/`clmv`/`Flwv`
  (`FXPreferredViewStyle`), search scopes `SCev`/`SCcf`/`SCsp`
  (`FXDefaultSearchScope`).
- Homebrew prefix is architecture-dependent: `/opt/homebrew` (Apple Silicon)
  vs `/usr/local` (Intel) — guard path-dependent config on
  `pkgs.stdenv.hostPlatform.isAarch64`.
- `duti` sets default handlers declaratively from activation scripts
  (e.g. `duti -s org.mozilla.firefox public.html all`).

## Dock

The dock builder walks `rbn.*` for aspects with `dock.{group,order}` set and
reads `meta.dock.app` for the bundle name. Group/order assignments belong to
users (`users/<name>.nix`); this aspect just materializes the layout.

## Fonts

Fonts are a system concern (`system/fonts`), consumed by both theming and
individual apps — don't declare fonts per-program.
