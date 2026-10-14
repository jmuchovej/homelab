## Context

See `proposal.md` — Why, and "What this is — and what it is not" for the relay-vs-compute finding that bounds this work.

The constraints that actually shape the design, verified against the upstream checkout at self-host `1.1.11`:

- **Upstream publishes no container image.**
  CI builds both `Dockerfile` (standalone/PGlite) and `Dockerfile.server` (full/Postgres) and smoke-tests them, but pushes neither.
  The npm package `happy-server-self-host` is published and carries a `bun` bundle of **`standalone.ts` only** (`dist/standalone.mjs`), the Prisma schema and migrations, the Prisma CLI, and the pre-built web app under `webapp/`.
  `main.ts` is not reachable from the package.
- **The two entrypoints differ in what they serve, not in what they require.**
  Redis is optional in both: `main.ts` pings it only `if (process.env.REDIS_URL)`, and the only other consumer is the Socket.IO redis-streams adapter in `socket.ts`, also gated on `REDIS_URL`, for multi-process fan-out.
  S3 is optional in both: `storage/files.ts` sets `useLocalStorage = !process.env.S3_HOST` and falls back to `${DATA_DIR}/files`.
  `storage/redis.ts` is imported by nothing.
  What differs: `main.ts` calls `startMetricsServer()` (a second Fastify on `METRICS_PORT`, default 9090, serving `/metrics` and `/health`, gated by `METRICS_ENABLED !== 'false'`) but calls `startApi()` **without** `staticDir`/`injectHtmlConfig`, so it serves no web UI.
  `standalone.ts serve` → `startServer` passes the static dir and injection through, runs `startDatabaseMetricsUpdater()` and `enableMonitoring()` (so request counters and DB gauges land in prom-client's default registry), but never starts the metrics listener — metrics are collected and unserved.
- **Database selection is one environment variable.**
  `createClient()` branches on `DB_PROVIDER`, returning a PGlite-adapter client for `"pglite"` and a plain `new PrismaClient()` otherwise.
  The Prisma datasource is natively `provider = "postgresql", url = env("DATABASE_URL")`; PGlite is the deviation, reached through the `driverAdapters` preview feature.
  `startServer` defaults `DB_PROVIDER` only when unset (`||`), so an explicitly-set `postgres` survives into `db.ts`.
- **The package's own `migrate` verb is PGlite-only.**
  `runMigrations()` instantiates PGlite directly and replays migration SQL into it.
  It cannot migrate an external Postgres.
- **Route surface.**
  Everything the non-browser clients call is under `/v1`, `/v2`, `/v3`, or `/socket.io`; uploaded files are served under `/files/*`; `/health` is on the main API via `enableMonitoring`.
  The SPA is served at `/` with an index fallback for client-side routes.
- **Client server resolution.**
  The web client resolves its server as `custom-server-url` (MMKV, set in Settings) → `window.__HAPPY_CONFIG__.serverUrl` (injected by the relay) → build-time `EXPO_PUBLIC_HAPPY_SERVER_URL` → `https://api.cluster-fluster.com`.
  `getVoiceServerUrl()` returns the public default unless `use-custom-server-for-voice` is set, regardless of the server setting.
- **History is portable.**
  Auth is a signed challenge over the client's keypair (`POST /v1/auth`), so the same `~/.happy/access.key` is the same account on any relay.
  Sessions carry `tag` (client-chosen, server deduplicates on it), encrypted `metadata`/`agentState`, and an encrypted per-session `dataEncryptionKey`; messages carry `localId` (server deduplicates on it) and encrypted `content`; machines carry a client-chosen `id`.
  Reads: `GET /v2/sessions` (cursor, `limit ≤ 200`), `GET /v3/sessions/:id/messages` (paginated), `GET /v1/machines`, `GET /v1/projects`, `GET /v1/kv`, `GET /v1/account/profile`; the `/v1` list routes cap at 150 and are not suitable.
  Writes: `POST /v1/sessions` (`tag`, `metadata`, `agentState`, `dataEncryptionKey`, `projectId`), `POST /v3/sessions/:id/messages` (batch of `{localId, content}`, server allocates `seq` in order), `POST /v1/machines`, `POST /v1/projects`, `POST /v1/kv/bulk`.
  Server-assigned ids and timestamps are not settable.
- **Cluster contract** (`kubernetes/AGENTS.md`): app-template HelmReleases via per-app `OCIRepository`; digest-pinned images; per-site namespaces (`local-ai` included) are selected per-app from the cluster's `apps/kustomization.yaml`; all storage classes are `reclaimPolicy: Delete` with no volsync; Cilium policy lockdown is opt-in per pod and must never be added prophylactically; authentik applications are discovered from `HTTPRoute`s wearing `authentik.rbn/*` labels, keyed on the route **name**, with `hostnames[0]` as the external host.
- **The repo has no container build of any kind** — no Dockerfile and no image workflow; `.github/workflows/flux-local.yaml` filters on `kubernetes/**/*`.

## Goals / Non-Goals

**Goals:**

- A relay reachable at a stable public hostname that CLI, mobile, desktop, and web clients all use, with no dependency on the public Happy service.
- Persistence on the cluster's existing CNPG path, with migrations that gate the rollout rather than racing it.
- An image build that is boring, reproducible from a version tag, and does not drag a pnpm monorepo into this repository.
- A deployment that fails loudly if the served web client is not bound to this relay's origin.
- The web UI behind authentik like every other browser app here, without breaking a single non-browser client.
- Metrics served where the incoming prometheus changeset can scrape them.
- Existing history carried over once, so the cutover does not start from an empty catalog.

**Non-Goals (design-level, beyond the proposal's):**

- Multi-cluster.
  `en.jm0.io` stays untouched.
- High availability.
  Single relay replica; the CNPG cluster is single-instance like every other app's.
  This is also why Redis stays unset — the streams adapter only matters past one replica.
- A reusable migration tool.
  The history copy runs once, from the workstation, and is discarded; nothing about it enters the repo's tooling surface.

## Decisions

### D1: Thin image over the npm package, not a monorepo build

**Chosen:** `kubernetes/containers/happy-server/Dockerfile` — `FROM node:22-slim`, `npm install -g happy-server-self-host@<version>`, run the `happy-server` binary.
The package's `postinstall` runs `prisma generate` against the shipped schema, so the image gets a real Prisma client with the correct native query engine for its platform.

**Why:** The published package is upstream's released, test-gated self-host artifact (`prepublishOnly` runs the server test suite), and it is the only artifact that carries the web app.
Building upstream's Dockerfiles means vendoring a pnpm workspace, a `bun` bundling step, and an Expo web export, all pinned to a git ref rather than a release, on a `node:20` base with ffmpeg and python3.

**Alternatives:**

- _Build upstream's `Dockerfile`_ — closest to what upstream CI tests, but it is the PGlite variant, so it does not match the chosen persistence anyway.
- _Build upstream's `Dockerfile.server`_ — runs `main.ts`, which brings the metrics listener for free but serves **no web UI**.
  The only browser client would then be upstream's hosted `app.happy.engineering` pointed at the relay through its custom-server setting — a third-party-served SPA, which is exactly what the origin-binding requirement exists to prevent.
  Restoring the UI would mean a second image (nginx serving `webapp/` with `sub_filter` injection and an index fallback).
  Redis and S3 are not a factor either way; both are optional in `main.ts` too.
- _Nix-package it_ — most consistent with the rest of the repo, but packaging Expo output, `sharp`, and the PGlite wasm blob through Nix is disproportionate.

**Consequences:** `node:22-slim` must carry the OpenSSL the Prisma engine links against; `sharp` pulls a per-platform native binary at install time, so the image must be built for the cluster's architecture.
Both are verified at build time, not discovered at rollout.
Every Linux node in the fleet is `x86_64` (`den.hosts.x86_64-linux.*` for `da-gr75`, `da-vcx-1`, `da-vcx-2`, `en-t65-1`; `da-n1x` is the darwin workstation and runs nothing in-cluster), so the build is single-arch `linux/amd64`.

### D2: Standalone entrypoint against external Postgres

**Chosen:** Run `happy-server serve` with `DB_PROVIDER=postgres` and a `DATABASE_URL` pointing at the app's CNPG cluster.

**Why:** It is the only entrypoint the package ships and the only one that serves the web UI (D1), and CNPG is where this cluster keeps relational state.
Redis and S3 stay unset because nothing needs them at one replica with local uploads — not because this entrypoint avoids them.

**Alternatives:**

- _PGlite on a PVC_ — the CI-tested self-host path and genuinely simpler, but it puts all session history in an embedded single-pod database with no backup story, outside the CNPG tooling the rest of the cluster uses.
- _`main.ts` + CNPG_ — fully within upstream's tested envelope, at the cost of the web UI (D1).

**Risk this carries:** upstream CI never exercises this pairing.
It is sound by inspection, but T1 proves it locally against a throwaway Postgres before any cluster manifest is written.
If it fails, the fallback is PGlite on a PVC, which changes the persistence decision but not the rest of the design.

### D3: Migrations as a Flux-gated Job, not a container entrypoint

**Chosen:** A Kubernetes `Job` running `prisma migrate deploy --schema=<pkg>/prisma/schema.prisma` from the same image, placed so Flux waits on it before the Deployment rolls.

**Why:** The image's own `happy-server migrate` is PGlite-only and would silently migrate the wrong database — the worst available failure.
`prisma migrate deploy` is the correct verb, is shipped in the package, and is exactly what upstream's own production deploy recipe runs as a one-off Job before applying the Deployment.
Running it as an init container instead would re-run it on every pod restart and offers no gate if it fails after the old pod is already gone.

**Alternatives:**

- _Init container_ — simpler, but couples migration to pod lifecycle and gives no clean "migration failed, keep the old version serving" behavior.
- _Manual `kubectl exec`_ — no.

**Consequences:** Upstream's schema changes must stay backward-compatible across one release, since migrations land before the old pod stops.
Upstream states this constraint for their own rolling updates, so it holds by construction.
`.zed/settings.json` has no glob for `job.yaml`; one is added so the manifest gets schema validation like its siblings.

### D4: Origin injection is a startup precondition, not a default

**Chosen:** Set `HAPPY_INJECT_HTML_CONFIG` to `{"serverUrl":"https://happy.${DC_DOMAIN}","disableAnalytics":true}` explicitly, and verify the served HTML carries it as an acceptance step.

**Why:** Unset the variable and the web UI still loads, still pairs, still streams output — against the public server.
Nothing fails; there is no error and no banner, only Settings → Server reading "default" and devtools showing the wrong host.
Upstream's own self-host plan calls this "the worst possible failure mode: exfiltrates data the user thought was staying local."

`PUBLIC_URL` is set to the same hostname separately: `resolveBaseUrl()` prefers it and otherwise reconstructs from forwarded headers, which would mint avatar and attachment URLs against whatever host the gateway forwards.

**What the relay cannot fix:** the voice default.
`getVoiceServerUrl()` ignores the injected server unless the client's "use custom server for voice" toggle is on, so voice-token requests go to the public service by default.
Voice is unconfigured here (proposal, Non-goals), so the practical effect is a leaked token request that then fails on the public side; the cutover checklist flips the toggle on each client anyway, and the spec records the default.
The mobile app has no injection path at all and relies on the explicit custom-server setting.

### D5: Authentik gates the web UI; the API routes bypass it

**Chosen:** Three raw `HTTPRoute`s on `happy.${DC_DOMAIN}`, all `envoy-external`, plus one `SecurityPolicy`:

- `happy` — `PathPrefix /` → the relay.
  Wears `authentik.rbn/enabled: "true"` and the `authentik.rbn/*` annotations (name, group, icon, access), and is the sole `targetRef` of the `SecurityPolicy`.
- `happy-api` — `PathPrefix` `/v1`, `/v2`, `/v3`, `/socket.io`, `/files`, `/health` → the relay.
  No labels, not targeted.
- `happy-outpost` — `PathPrefix /outpost.goauthentik.io` → `${AK_OUTPOST_PROXY}`, the house auth-flow route.

**Why:** Gateway API matching prefers the longest path prefix, so every call the CLI daemon, mobile app, desktop app, and the SPA's own XHR/WebSocket traffic make lands on `happy-api` and reaches the relay's public-key authentication untouched.
Only the initial document load of the SPA passes through the outpost.
Raw routes rather than app-template `route:` values because a second route key makes the chart name routes `<app>-<key>`, and authentik discovery keys on the route name (the `linkding` precedent).

**Alternatives:**

- _No gate at all_ (the previous D5) — correct that the relay's own auth is the boundary, but it leaves the UI open to anyone who finds the hostname and keeps the app off the authentik dashboard for no reason.
- _One route, `SecurityPolicy` on a named rule via `targetRefs[].sectionName`_ — fewer objects; Envoy Gateway 1.8.1 should support it, but the three-route shape is already proven in this tree.
  Revisit if the route count ever matters.

**Consequences:** This is a **visibility gate on the SPA bytes, not a security boundary**.
`/v1/auth` is as reachable as before, open registration is unchanged, and the spec says both.
`/files/*` must stay on `happy-api` because the mobile app fetches avatars and attachments from it.
When the authentik session expires, the already-loaded SPA keeps working (its calls are ungated); only a reload re-authenticates.

### D6: Namespace `local-ai`, per-app selection on `da` only

**Chosen:** `kubernetes/apps/local-ai/happy/`, selected from `clusters/da.jm0.io/apps/kustomization.yaml` in the `local-ai` block.

**Why:** `local-ai` is the AI-tooling namespace — it already holds a vector store and a chat UI alongside the inference server, so "inference only" was never its boundary.
A control plane for coding agents belongs with them.
It is selected per-app like `home`, so nothing about cluster selection changes.

### D7: A PVC until S3 lands

Uploaded assets (avatars, attachments) do not live in Postgres.
With `S3_HOST` unset, `storage/files.ts` writes to `${DATA_DIR}/files` on local disk.
So the Deployment needs a small RWO `zfs-ssd` claim and `strategy: Recreate` — the same shape as `linkding`, for the same reason.
When the cluster gains an S3 service, setting `S3_HOST`/`S3_BUCKET`/`S3_ACCESS_KEY`/`S3_SECRET_KEY`/`S3_PUBLIC_URL` moves uploads there and retires both the claim and `Recreate`; that is an env edit in a later change, not a redesign.

### D8: DB LoadBalancer octet 61

Octets 51–60 are taken (authentik 51, home-assistant 52, radarr 53, sonarr 54, lidarr 55, readarr 56, prowlarr 57, homebox 58, immich 59, split-pro 60).
61 is the next free address in the `.5x` DB convention.

### D9: Metrics via an upstream flag on the standalone entrypoint

**Chosen:** Contribute a small change to `packages/happy-server/sources/standalone.ts` so `serve()` calls the existing `startMetricsServer()` when `METRICS_ENABLED=true`, pin the `happy-server-self-host` release that carries it, set `METRICS_ENABLED=true` and `METRICS_PORT=9090` in the HelmRelease, and expose `9090` as a named `metrics` port on the Service.

**Why:** The standalone process already populates prom-client's default registry (request counters, WebSocket counters, DB gauges) and `startMetricsServer()` already exists one import away; the entrypoint simply never calls it.
Opt-in rather than `main.ts`'s opt-out keeps standalone's single-port default for everyone else.
This is the smallest change that gives the thin image the same `/metrics` production has.

**Alternatives:**

- _Switch to `main.ts`_ — metrics for free, web UI lost (D1).
- _A wrapper entry in the image that imports `prom-client` and serves the registry itself_ — works because the bundle externalizes `prom-client`, but the bundle's CLI only runs when `argv[1]`'s basename is one of its own names, so the wrapper has to impersonate it.
  Too clever for a five-line upstream fix.

**Consequences:** `/metrics` is unauthenticated on the pod port and is **not** routed through the gateway; it is reachable in-cluster only, which is where the scraper lives.
The `ServiceMonitor` (or `PodMonitor`) is the prometheus changeset's to write.
Until the patched release exists, the image pin cannot satisfy the metrics requirement; the task is ordered so nothing else waits on it, and the spec scenario is simply unmet rather than faked.

### D10: The image tree lives at `kubernetes/containers/`

**Chosen:** `kubernetes/containers/<image-name>/` as a fifth top-level sibling of `clusters/`, `core/`, `apps/`, `components/`, documented in `kubernetes/AGENTS.md`'s Layout block.

**Why:** The image exists only to be consumed by manifests in this tree, and putting it beside the app under `apps/local-ai/happy/` would make that directory the one place in the catalog holding something other than Flux-selectable manifests.
Staying under `kubernetes/` means the existing `kubernetes/**` rule covers it — no new root tree, no `repo-layout` change, no new `AGENTS.md` or `.agents/rules` symlink.

**Consequences:** `.github/workflows/flux-local.yaml` filters on `kubernetes/**/*`, so a Dockerfile edit also triggers a flux-local run.
Harmless (the build does not read it); noted, not fixed here.
The image workflow's own path filter is `kubernetes/containers/happy-server/**`.

### D11: History is copied once with a disposable script

**Chosen:** A one-shot script, run from the workstation that owns `~/.happy/access.key`, that authenticates to both relays with that key and copies the account's state from the public service to the new relay over the HTTP API.
It is written for this move, verified against the throwaway Postgres from T1 first, run once, and discarded.

**Why it works:** same keypair, same account; every blob is ciphertext the server never interprets; the write routes accept the same fields the read routes return.
Reads use the paginated `/v2` sessions and `/v3` messages routes, never the 150-capped `/v1` lists.

**Order and mechanics:**

1. Machines — `POST /v1/machines` with the client-chosen `id`, `metadata`, `daemonState`, `dataEncryptionKey` verbatim.
2. Projects — `POST /v1/projects`; record old→new id.
3. Sessions — `POST /v1/sessions` with `tag`, `metadata`, `agentState`, `dataEncryptionKey`, and the remapped `projectId`; record old→new id.
   The server matches on `tag`, so a re-run finds the existing row instead of duplicating.
4. Messages — per session, read all pages ascending by `seq`, write in batches to `POST /v3/sessions/:newId/messages` as `{localId, content.c}`.
   The server allocates `seq` in arrival order and deduplicates on `localId`, so ordering is preserved and re-runs are idempotent.
5. KV — `GET /v1/kv` → `POST /v1/kv/bulk`.
6. Account profile and settings.
7. Rewrite the session ids in `~/.happy/sessions.json` through the old→new map so `happy resume <id>` finds them on the new relay.

**Not carried:** attachments and avatars (bytes on the public service's S3 behind presigned URLs; re-upload is best-effort and skipped if it fights back), push tokens (clients re-register), friends and feed (unused), service tokens (none exist).

**Consequences:** server-assigned ids and `createdAt`/`updatedAt` change — history keeps its order but is stamped with the migration time.
Sessions arrive inactive (`active` is presence-derived), which is correct.
The daemon must be stopped during the copy so no session is written on both sides.

## Risks / Trade-offs

**[Untested entrypoint/provider pairing]** → T1 proves `DB_PROVIDER=postgres` + standalone locally against a throwaway Postgres before any manifest is written.
Fallback is PGlite on a PVC, which changes D2 alone.

**[Silent fallback to the public server]** → D4 sets the injection explicitly, and acceptance includes fetching `/` and asserting `__HAPPY_CONFIG__` names the relay's own origin.
Without that assertion the failure is invisible.

**[Voice leaks to the public server by default]** → client-side; the relay cannot override it.
Recorded in the spec; the cutover checklist sets "use custom server for voice" on every client even though voice is unconfigured.

**[The UI gate reads as a boundary it is not]** → D5 and the spec state plainly that `/v1/auth` is open and the gate only covers the SPA bytes.
Narrowing registration later means an allowlist at the gateway or an `ingress.rbn/*` grant, not ext-auth.

**[PVC or CNPG deletion destroys session history]** → All classes are `reclaimPolicy: Delete` and there is no volsync.
The CNPG `Cluster` carries `prune: disabled` via the component; the app's own PVC does not and cannot (the cluster contract applies that guard to CNPG clusters only).
Accepted: the relay holds convenience state, not source of truth — code lives on workstations.

**[Open registration on a public hostname]** → Accepted and recorded in the spec; unchanged by D5.
Accounts are inert without a paired machine.
Revisit with a gateway allowlist if it is ever abused.

**[npm supply chain]** → The image installs a published npm package at build time.
Pin the exact version in the Dockerfile and the resulting image by digest in the HelmRelease, so a rebuild cannot silently change what runs.

**[Upstream churn]** → `happy-server` is `private: true` and upstream treats the self-host package as a publishing shell around it.
The env contract (`DB_PROVIDER`, `HAPPY_STATIC_DIR`, `HAPPY_INJECT_HTML_CONFIG`, `DATA_DIR`, and now `METRICS_ENABLED`/`METRICS_PORT`) is not a documented public API and may shift between releases.
Version bumps get a smoke test, not a blind rollout.

**[Metrics wait on an upstream release]** → D9's flag has to be merged and published before the image can serve `/metrics`.
Sequenced last among the image tasks so the deployment does not block on it; the spec scenario stays visibly unmet until the pin moves.

**[Migration rewrites ids and timestamps]** → D11 accepts it: order survives through `seq`, resume survives through the `sessions.json` rewrite, and the public-service account stays intact as the fallback until the new relay is trusted.

## Migration Plan

Sequence, once the relay passes acceptance (tasks §6):

1. **Freeze.**
   Stop the workstation daemon so no session is written to the public service mid-copy.
2. **Copy** (D11) — dry-run against the throwaway Postgres from T1, then for real against the relay.
   Verify session, message, and machine counts match the public service's, and that one migrated session opens with its full history in the web UI.
3. **Repoint** each client, with no fallback by design — if the relay is unreachable, requests fail loudly rather than reverting to the public server:
   - CLI: set `serverUrl` in `~/.happy/settings.json` (or `HAPPY_SERVER_URL`), start the daemon, re-pair.
   - Web: browse to the relay hostname; sign in through authentik; pair from there.
   - Mobile: point the in-app server setting at the relay hostname, enable "use custom server for voice", re-pair.
4. **Resume.**
   Running Claude Code work continues through `happy resume <id>` against the remapped ids; the Happy transcript on the relay shows the copied history, and the model context comes from the local transcript as always.

**Rollback:** clear `serverUrl` on each client to return to the public service, whose account is untouched by the copy; the cluster-side objects can be pruned by removing the app from the cluster's `apps/kustomization.yaml`.
Note that pruning deletes the PVC and its data — the CNPG cluster survives via `prune: disabled` and needs a deliberate `kubectl delete`.

## Open Questions

- **Version bump cadence.**
  Whether to wire Renovate for the npm pin and the image digest, or bump by hand.
  Deferred; it changes no manifest written here.
- **Upstream turnaround on D9.**
  If the `METRICS_ENABLED` change does not land before the prometheus changeset wants to scrape, the interim is to build the image from a fork tag rather than the published package — a deviation from D1 worth avoiding, so ship the PR early.
