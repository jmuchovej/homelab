# programs/ — application & tool configs

One aspect per program: `rbn.programs._.<category>._.<name>`, referenced as
`<rbn/programs/<category>/<name>>`. An aspect may legitimately carry **both**
system-level (`os`/`nixos`/`darwin`) and user-level (`homeManager`) keys —
scope is a per-program decision, not a rule that programs are HM-only.

## Scope: user vs system

Ideal default is **user scope** (`homeManager`): a program that follows the
user works on hosts where they have no root (HPC clusters and other managed
systems) — HM is the only layer guaranteed everywhere. From there, add system
scope when the criteria say so:

- **System-wide default**: the tool should replace a built-in for every
  user, root, and scripts (eza, rg, fd over their ancient system
  counterparts) → install at `os` level too.
- **Root access**: if the fleets this program targets include hosts where
  system-level install is impossible, the user-scoped half must be able to
  stand alone — don't hide required config behind the system half.
- **Homebrew-only on macOS**: Homebrew installs are system-level by nature.
  darwin homebrew contributions (`casks`/`brews`/`masApps`) are declared
  unconditionally — they are inert unless the `<rbn/system/homebrew>` aspect
  is present (nix-darwin's `homebrew.enable`, which that aspect sets, gates
  realization; the options themselves do nothing when it's absent). When a
  program can only come from Homebrew there, its NixOS counterpart typically
  also installs at the system level, keeping the aspect symmetric across
  platforms.

The layering (system-wide install/default + user-level configuration or
override) is **deliberate and lives in the one owning aspect**. The
anti-pattern is _accidental_ duplication: two different aspects installing or
configuring the same tool, or the same tool arriving via both Homebrew and
nixpkgs on one host — that's PATH shadowing and activation conflicts.

## Taxonomy (the method)

Categories are directories; a flat `<category>.nix` file is a category whose
members are too small to split (e.g. `social.nix`, `media.nix`,
`creative.nix`). Current categories: `browsers/`, `desktop/`, `development/`
(language toolchains), `documents/`, `editors/`, `emulators/` (terminal
emulators), `security/`, `terminal/` (CLI tools), `toolchains/`, `vcs/`, plus
`baseline.nix` (universal CLI floor) and `databases.nix`.

- **Editors are their own category**, deliberately not under `development/`.
- A program joins a _suite_ (`suites/common.nix`) or a _user's_ includes —
  programs never include each other except through genuine dependency.

## Conventions

- **One aspect owns each program and each dotfile.** Others extend through
  that aspect's options, never by writing the same file.
- **Dock placement does not live here.** Users assign
  `rbn.programs.…<name>.dock = { group; order; }` (or `.provides.<app>.dock`)
  in their own file — see `users/AGENTS.md`. A program aspect at most carries
  `meta.dock.app` naming its .app bundle.
- Per-user identity (git user.name etc.) currently lives inline in program
  aspects — acceptable while there's effectively one human user; revisit if
  that changes.
