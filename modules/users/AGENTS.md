---
paths:
  - "modules/users/**"
---

# users/ — people and accounts

One file per user.
Each defines:

- **`den.aspects.<user>`** — identity (`meta.{email,fullname,username}`), batteries (`<den/primary-user>`, `den.batteries.user-shell "zsh"`), a suite, and the user's program selection.
  Desktop-only programs ride a parametric include guarded on `host.desktop or false`.
- **Host membership** — `den.hosts.<system>.<host>.users.<user> = { };` declared HERE (the user file), not in `hosts/`.
  Commented-out memberships are deliberate toggles.
- **Dock layout** — on the host-user entry (`den.hosts.<system>.<host>.users.<user>.dock`), one attrset per group: `dock.<group> = { order; apps = [ … ]; }`.
  Groups render by `order` with a spacer between them; apps render in list order.
  An app is normally just its `dock.key` string, resolved against the aspects in that user's tree plus the macOS built-ins `system/dock` knows (`System Settings`, `Messages`, `Safari`, `Activity Monitor`).
  Something nothing in the tree installs takes an inline `{ key; source; }` or `{ key; path; }`.
  A key no aspect declares is an eval error, never a silently missing icon.
  Group orders are hundreds (100 system, 200 communication, 300 browsers, 400 PKM, 500 development) so a group can be slotted in without renumbering.

`nix-trusted-user.nix` and `root.nix` are account plumbing, not people.
