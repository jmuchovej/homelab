# classes/ — cross-cutting host/user behaviors

Not aspects but **den schema/forwarding machinery** — behaviors that key off
host/user metadata rather than being included by name:

- `roles.nix` — role-based dispatch: forwards each role in
  `host.roles ∩ user.roles` as a class to the host's real class. A role
  applies only when BOTH the host offers it and the user holds it.
- `persistence.nix` — impermanence wiring, driven by `host.persistence.*`
  schema (device, extra-directories/files).
- `desktop.nix` — the `host.desktop` flag other aspects condition on
  (`host.desktop or false` in parametric includes).

Add here only when behavior must span many aspects based on metadata; if it
can be a normal included aspect, it belongs in the other directories.
