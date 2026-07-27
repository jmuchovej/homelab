# users/ — people and accounts

One file per user. Each defines:

- **`den.aspects.<user>`** — identity (`meta.{email,fullname,username}`),
  batteries (`<den/primary-user>`, `den.batteries.user-shell "zsh"`), a suite,
  and the user's program selection. Desktop-only programs ride a parametric
  include guarded on `host.desktop or false`.
- **Host membership** — `den.hosts.<system>.<host>.users.<user> = { };`
  declared HERE (the user file), not in `hosts/`. Commented-out memberships
  are deliberate toggles.
- **Dock layout** — the user assigns `dock = { group; order; }` onto program
  aspects (`rbn.programs._.…` or their `provides`) at the top of their file;
  the dock builder (`system/dock`) collects these. Ordering convention:
  hundreds-band per group (100 development, 200 communication/media, 300
  browsers, 400 PKM, 500 editors, 600 terminals).

`nix-trusted-user.nix` and `root.nix` are account plumbing, not people.
