## Context

See `proposal.md` — Why, and "What this is — and what it is not" for the
relay-vs-compute finding that bounds this work.

The constraints that actually shape the design:

- **Upstream publishes no container image.** CI builds both `Dockerfile`
  (standalone/PGlite) and `Dockerfile.server` (full/Postgres) and smoke-tests
  them, but pushes neither. The npm package `happy-server-self-host` (1.1.11) is
  published and carries the server bundle, the Prisma schema and migrations, the
  Prisma CLI, and a pre-built web app.
- **Two entrypoints exist, with different dependency sets.** `main.ts` (the
  hosted production path) requires `DATABASE_URL`, `REDIS_URL`, and S3 config.
  `standalone.ts serve` → `startServer` connects the DB, inits crypto, loads file
  storage, starts the API, and never touches Redis. The npm package's
  `happy-server` binary runs the standalone entrypoint.
- **Database selection is one environment variable.** `createClient()` branches
  on `DB_PROVIDER`, returning a PGlite-adapter client for `"pglite"` and a plain
  `new PrismaClient()` otherwise. The Prisma datasource is natively
  `provider = "postgresql", url = env("DATABASE_URL")`; PGlite is the deviation,
  reached through the `driverAdapters` preview feature.
- **`startServer` defaults `DB_PROVIDER` only when unset** (`||`), so an
  explicitly-set `postgres` survives into `db.ts`.
- **The package's own `migrate` verb is PGlite-only.** `runMigrations()`
  instantiates PGlite directly and replays migration SQL into it. It cannot
  migrate an external Postgres.
- **The repo has no container build of any kind** — no Dockerfile, no image
  workflow, and `packages/` is a Nix `by-name` tree. This change introduces the
  first one.
- **Cluster contract** (`kubernetes/AGENTS.md`): app-template HelmReleases via
  per-app `OCIRepository`; digest-pinned images; `home` namespace apps are
  selected per-app from the cluster's `apps/kustomization.yaml`; all storage
  classes are `reclaimPolicy: Delete` with no volsync; Cilium policy lockdown is
  opt-in per pod and must never be added prophylactically.

## Goals / Non-Goals

**Goals:**

- A relay reachable at a stable public hostname that CLI, mobile, desktop, and
  web clients all use, with no dependency on the public Happy service.
- Persistence on the cluster's existing CNPG path, with migrations that gate the
  rollout rather than racing it.
- An image build that is boring, reproducible from a version tag, and does not
  drag a pnpm monorepo into this repository.
- A deployment that fails loudly if the served web client is not bound to this
  relay's origin.

**Non-Goals (design-level, beyond the proposal's):**

- Prometheus metrics. The standalone entrypoint does not start the separate
  metrics server that `main.ts` does, and the cluster has no Prometheus stack to
  scrape it.
- GitHub OAuth, ElevenLabs voice, and RevenueCat integrations. All are
  env-gated and stay unconfigured; `connectRoutes` hardcodes an
  `app.happy.engineering` redirect that upstream lists as unresolved for
  self-host.
- Multi-cluster. `en.jm0.io` stays untouched.
- High availability. Single relay replica; the CNPG cluster is single-instance
  like every other app's.

## Decisions

### D1: Thin image over the npm package, not a monorepo build

**Chosen:** `containers/happy-server/Dockerfile` — `FROM node:22-slim`,
`npm install -g happy-server-self-host@<version>`, run the `happy-server` binary.
The package's `postinstall` runs `prisma generate` against the shipped schema, so
the image gets a real Prisma client with the correct native query engine for its
platform.

**Why:** The published package already contains everything the monorepo build
produces — the bundled server, the schema, the migrations, the Prisma CLI, and
the pre-built web app. Building upstream's Dockerfile means vendoring a pnpm
workspace, a `bun` bundling step, and an Expo web export, all pinned to a git ref
rather than a release.

**Alternatives:**

- _Build upstream's `Dockerfile`_ — closest to what upstream CI tests, but it is
  the PGlite variant, so it does not match the chosen persistence anyway.
- _Build upstream's `Dockerfile.server`_ — matches Postgres, but runs `main.ts`,
  which reintroduces the Redis requirement for no benefit.
- _Nix-package it_ — most consistent with the rest of the repo, but packaging
  Expo output, `sharp`, and the PGlite wasm blob through Nix is disproportionate.

**Consequences:** `node:22-slim` must carry the OpenSSL the Prisma engine links
against; `sharp` pulls a per-platform native binary at install time, so the image
must be built for the cluster's architecture. Both are verified at build time,
not discovered at rollout. Every Linux node in the fleet is `x86_64`
(`den.hosts.x86_64-linux.*` for `da-gr75`, `da-vcx-1`, `da-vcx-2`, `en-t65-1`;
`da-n1x` is the darwin workstation and runs nothing in-cluster), so the build is
single-arch `linux/amd64`.

### D2: Standalone entrypoint against external Postgres

**Chosen:** Run `happy-server serve` with `DB_PROVIDER=postgres` and a
`DATABASE_URL` pointing at the app's CNPG cluster.

**Why:** It is the only combination that gets CNPG persistence without Redis.
The full `main.ts` entrypoint pings Redis at boot and aborts if it cannot, which
would mean adding a valkey dependency purely to satisfy a startup check for a
client the standalone path never uses.

**Alternatives:**

- _PGlite on a PVC_ — the CI-tested self-host path and genuinely simpler, but it
  puts all session history in an embedded single-pod database with no backup
  story, outside the CNPG tooling the rest of the cluster uses.
- _`main.ts` + CNPG + valkey_ — fully within upstream's tested envelope, at the
  cost of a Redis dependency that exists only to be pinged.

**Risk this carries:** upstream CI never exercises this pairing. It is sound by
inspection, but T1 proves it locally against a throwaway Postgres before any
cluster manifest is written. If it fails, the fallback is PGlite on a PVC, which
changes the persistence decision but not the rest of the design.

### D3: Migrations as a Flux-gated Job, not a container entrypoint

**Chosen:** A Kubernetes `Job` running
`prisma migrate deploy --schema=<pkg>/prisma/schema.prisma` from the same image,
placed so Flux waits on it before the Deployment rolls.

**Why:** The image's own `happy-server migrate` is PGlite-only and would silently
migrate the wrong database — the worst available failure. `prisma migrate deploy`
is the correct verb, is shipped in the package, and is exactly what upstream's own
production deploy recipe runs as a one-off Job before applying the Deployment.
Running it as an init container instead would re-run it on every pod restart and
offers no gate if it fails after the old pod is already gone.

**Alternatives:**

- _Init container_ — simpler, but couples migration to pod lifecycle and gives no
  clean "migration failed, keep the old version serving" behavior.
- _Manual `kubectl exec`_ — no.

**Consequences:** Upstream's schema changes must stay backward-compatible across
one release, since migrations land before the old pod stops. Upstream states this
constraint for their own rolling updates, so it holds by construction.

### D4: Origin injection is a startup precondition, not a default

**Chosen:** Set `HAPPY_INJECT_HTML_CONFIG` to
`{"serverUrl":"https://happy.${DC_DOMAIN}","disableAnalytics":true}` explicitly,
and verify the served HTML carries it as an acceptance step.

**Why:** `getServerUrl()` in the web client ends its fallback chain at
`DEFAULT_SERVER_URL = 'https://api.cluster-fluster.com'`. Unset the variable and
the web UI still loads, still works, and talks to the public server — upstream's
own self-host plan calls silent fallback "the worst possible failure mode:
exfiltrates data the user thought was staying local." There is no in-app signal
that it happened.

`PUBLIC_URL` is set to the same hostname separately: `resolveBaseUrl()` prefers
it and otherwise reconstructs from forwarded headers, which would mint
avatar and attachment URLs against whatever host the gateway forwards.

### D5: No authentik, and therefore no `SecurityPolicy`

**Chosen:** A plain `HTTPRoute` on `envoy-external`, with no `SecurityPolicy`,
no `authentik.rbn/enabled` label, and no outpost route.

**Why:** Happy's CLI daemon, mobile app, and desktop app are not browsers; they
cannot follow an outpost redirect. Gating the route would leave the web UI as the
only working client, which defeats the deployment. The relay's own signed-
challenge public-key authentication is the real boundary.

**Consequences:** The app does not appear in the authentik application dashboard,
and `/v1/auth` is reachable from the internet. Both are recorded in the spec as
accepted, not overlooked. Narrowing later means an allowlist at the gateway or an
`ingress.rbn/*` grant, not ext-auth.

### D6: Namespace `home`, per-app selection on `da` only

**Chosen:** `kubernetes/apps/home/happy/`, selected from
`clusters/da.jm0.io/apps/kustomization.yaml`.

**Why:** `home` is the per-site namespace for general self-hosted applications
and is already selected per-app. `local-ai` is for inference workloads
(ollama, chroma, open-webui); a sync relay is not one.

### D7: A PVC is still required, despite CNPG

Uploaded assets (avatars, attachments) do not live in Postgres. With `S3_HOST`
unset, `storage/files.ts` writes to `${DATA_DIR}/files` on local disk. So the
Deployment needs a small RWO `zfs-ssd` claim and `strategy: Recreate` — the same
shape as `linkding`, for the same reason.

### D8: DB LoadBalancer octet 61

Octets 51–60 are taken (authentik 51, home-assistant 52, radarr 53, sonarr 54,
lidarr 55, readarr 56, prowlarr 57, homebox 58, immich 59, split-pro 60). 61 is
the next free address in the `.5x` DB convention.

## Risks / Trade-offs

**[Untested entrypoint/provider pairing]** → T1 proves `DB_PROVIDER=postgres` +
standalone locally against a throwaway Postgres before any manifest is written.
Fallback is PGlite on a PVC, which changes D2 alone.

**[Silent fallback to the public server]** → D4 sets the injection explicitly, and
acceptance includes fetching `/` and asserting `__HAPPY_CONFIG__` names the
relay's own origin. Without that assertion the failure is invisible.

**[PVC or CNPG deletion destroys session history]** → All classes are
`reclaimPolicy: Delete` and there is no volsync. The CNPG `Cluster` carries
`prune: disabled` via the component; the app's own PVC does not and cannot
(the cluster contract applies that guard to CNPG clusters only). Accepted: the
relay holds convenience state, not source of truth — code lives on workstations.

**[Open registration on a public hostname]** → Accepted per D5 and recorded in
the spec. Accounts are inert without a paired machine. Revisit with a gateway
allowlist if it is ever abused.

**[npm supply chain]** → The image installs a published npm package at build
time. Pin the exact version in the Dockerfile and the resulting image by digest
in the HelmRelease, so a rebuild cannot silently change what runs.

**[Upstream churn]** → `happy-server` is `private: true` and upstream treats the
self-host package as a publishing shell around it. The env contract
(`DB_PROVIDER`, `HAPPY_STATIC_DIR`, `HAPPY_INJECT_HTML_CONFIG`, `DATA_DIR`) is
not a documented public API and may shift between releases. Version bumps get a
smoke test, not a blind rollout.

**[No metrics]** → Accepted; nothing scrapes them today. `/health` is registered
on the main API by `enableMonitoring`, so probes work without the metrics server.

## Migration Plan

There is no data to migrate — no export path exists from the public service, and
this is a clean start (proposal, Non-goals).

**Cutover**, per client, after the relay is healthy:

1. Web: browse to the relay hostname; pair from there.
2. CLI: set `serverUrl` in `~/.happy/settings.json` (or `HAPPY_SERVER_URL`),
   restart the daemon, re-pair. There is deliberately no fallback — if the relay
   is unreachable, requests fail loudly rather than reverting to the public
   server.
3. Mobile: point the in-app server setting at the relay hostname, re-pair.

Existing sessions on the public service are not carried over and remain
accessible there until the account is abandoned.

**Rollback:** clear `serverUrl` on each client to return to the public service;
the cluster-side objects can be pruned by removing the app from the cluster's
`apps/kustomization.yaml`. Note that pruning deletes the PVC and its data — the
CNPG cluster survives via `prune: disabled` and needs a deliberate
`kubectl delete`.

## Open Questions

- **Version bump cadence.** Whether to wire Renovate for the npm pin and the
  image digest, or bump by hand. Deferred; it changes no manifest written here.
