# services/ — system daemons

One aspect per service: `rbn.services._.<name>`, referenced as
`<rbn/services/<name>>`. A service is _selected_ by a host (listed in that
host's `includes`) — never self-enabling.

## Shape

- **Single `<name>.nix`** for most services. **A directory** when the service
  ships extra assets (`authentik/tofu-service-account.yaml`) or has genuine
  sub-aspects (`kubernetes/`, `local-llms/` → `<rbn/services/local-llms/ollama>`).
- **Per-host knobs** go through `den.schema.host`, colocated in the service
  file (cross-service flags like `tailscale.enable` live in `../schema.nix`).
  Hosts set them in `den.hosts.<system>.<name>` (see `hosts/AGENTS.md`);
  the aspect reads `host.<service>.*`.
- **Config style**: `lib.mkMerge` of secret blocks + the actual config;
  helpers from `lib.rbn` (`enabled`, `get-secret`/`get-secret'`,
  `merge-deep`, and the mesh trio `with-consul`, `mk-traefik-service`,
  `mk-healthcheck` for anything behind the service mesh).

## Secrets

`get-secret' config "<svc>/<key>"` declares the sops secret; compose env files
with `sops.templates."<svc>/env"` + `config.sops.placeholder.*` (see
`authentik.nix` for the full pattern). Declare explicit `owner`/`mode` on
secrets, and prefer systemd `LoadCredential` over paths in env/args where the
unit supports it.

## User-level services

- Linux: systemd user units (`systemctl --user`, `OnCalendar`/`Persistent`
  timers). macOS: launchd agents (`launchd.agents.*`, `ProgramArguments` /
  `StartCalendarInterval`). Cross-platform user services are written twice
  behind an `isLinux` split.
- If the HM half depends on a system daemon, the aspect must configure (or
  assert) both halves — enabling only the HM side silently breaks.
- macOS: some services/apps need one-time manual TCC permission grants in
  System Settings that cannot be automated — note it in the aspect when true.
