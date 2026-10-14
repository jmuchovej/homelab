# Deploy the self-hosted Happy sync relay

## Why

Happy (`slopus/happy`, formerly the `happy-coder` npm package) lets a phone or browser drive a Claude Code / Codex session running on a real workstation.
By default every one of those sessions round-trips through `https://api.cluster-fluster.com`, third-party infrastructure that holds the session catalog, message history, and machine presence for every project.
The payloads are end-to-end encrypted, but the metadata graph — which machines exist, which projects are open, when work happens — is not ours, and the service is a hard dependency for a tool that is otherwise entirely local.

Upstream ships a self-host path that removes that dependency, and the cluster already has every backing service it needs.
Standing it up on `da.jm0.io` moves the relay in-house without changing anything about how or where the agents actually run.

## What this is — and what it is not

Two findings from reading the upstream source govern the whole design, because both cut against the intuitive reading of "self-hosted Happy":

**The self-hosted server is strictly a relay.**
`happy-server` is Fastify + Socket.IO over Postgres, storing opaque client-encrypted blobs, plus presence heartbeats, push tokens, and an encrypted project catalog.
It never spawns an agent, never opens a shell, never holds a checkout, and never talks to a model API — `packages/happy-server/sources` contains zero references to `api.anthropic.com`, `api.openai.com`, or `generativelanguage`.
The only plaintext it handles is service tokens (GitHub, vendor keys), encrypted at rest under a key tree derived from `HANDY_MASTER_SECRET`.

**Projects are never synced.**
A `Project` row on the server is an encrypted catalog entry — external id, metadata blob, data key, avatar — and its own source comment states the server "only indexes the caller-owned external id and stores/serves opaque values."
Actual code is reached live, on demand, by RPC over the session socket (`bash`, `readFile`, `writeFile`, `listDirectory`, `getDirectoryTree`, `ripgrep`, `difftastic`), and those responses are transient.
Source lives in exactly one place: the filesystem of whichever machine runs the `happy` daemon.

So this change buys **data sovereignty over session metadata**, not cluster-side compute.
Agents keep running on workstations.
Getting them onto cluster nodes would mean a second, unrelated workload — a pod running `happy daemon start-sync` against a PVC you populate yourself — which is deliberately **out of scope here** (see Non-goals).

A third finding makes the history on the public server portable rather than stranded: because every stored blob is ciphertext under keys only the clients hold, and the account identity is the client's keypair, the same blobs are valid on any relay the same keypair authenticates to.
That is what lets this change carry existing history across instead of starting clean.

## What Changes

- **New app `kubernetes/apps/local-ai/happy/`** — an `app-template` HelmRelease running the relay, its `HTTPRoute`s on `envoy-external`, a small `PVC` for uploaded assets, and an `ExternalSecret` for `HANDY_MASTER_SECRET`.
- **New `happy-db.ks.yaml`** attaching the existing `kubernetes/components/cnpg-database` component, giving the relay its own CNPG cluster and credentials.
- **New `kubernetes/containers/happy-server/`** holding a thin `Dockerfile` over the published `happy-server-self-host` npm package, plus a GitHub Actions workflow that builds and pushes it to `ghcr.io`.
  Upstream publishes no container image, so this is the repository's first container build; it lives inside `kubernetes/` because the image exists only to be consumed by manifests in that tree.
- **Migrations run as a Flux-gated step**, not at container start, because the external-Postgres path needs `prisma migrate deploy` rather than the PGlite-only migrator baked into the package's `happy-server migrate`.
- **The relay serves its own web UI** at the same origin, with `HAPPY_INJECT_HTML_CONFIG` set explicitly — see Impact for why that is load-bearing rather than cosmetic.
- **The web UI is gated by authentik; the API is not.**
  The hostname is split across two routes: the SPA's `/` sits behind the outpost like every other browser app here, while the API prefixes the CLI, mobile, and desktop clients use pass straight through to the relay's own public-key authentication.
  The gate keeps casual visitors off the UI and puts the app on the authentik dashboard; it is not the security boundary, and the spec says so.
- **Prometheus metrics are exposed** on a dedicated port.
  The standalone entrypoint already collects them but never serves them; a small upstream change to `standalone.ts` starts the existing metrics listener behind `METRICS_ENABLED`, and this change pins the release that carries it.
  The scrape job itself belongs to the incoming prometheus changeset.
- **Existing session history is copied over** from the public service with a disposable one-shot script run from the workstation, before clients are repointed.

## Capabilities

### New Capabilities

- `happy-relay`: the self-hosted Happy sync relay as a cluster service — what it stores and what it refuses to store, its persistence and exposure contract, the client-origin binding that keeps self-hosted clients off the public server, the split between the identity-gated web UI and the ungated API, its metrics and image-provenance contract, the portability of history between relays, and the boundary between the relay and agent execution.

### Modified Capabilities

None.
The image tree lives under `kubernetes/`, so the root-tree contract in `repo-layout` is untouched.

## Impact

**Affected systems**

- `kubernetes/apps/local-ai/` — gains a `happy/` app directory.
- `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml` — selects the new app in the `local-ai` block.
  `en.jm0.io` is deliberately not wired up.
- `kubernetes/containers/` — new subtree; `kubernetes/AGENTS.md` gains a Layout entry for it.
- `cloudnative-pg` (namespace `databases`), `onepassword-connect` (namespace `external-secrets`), and `envoy-config` (namespace `network`) become `dependsOn` edges.
- authentik — the labelled UI route is discovered by `tofu/kubernetes/main.tofu` and becomes a proxy-provider application like `linkding` or `ollama`.
- 1Password vault `Homelab` — a new item holding the master secret.
- `ghcr.io` — a new package under the repo owner.
- `slopus/happy` upstream — one small PR to `packages/happy-server/sources/standalone.ts`.
- `.zed/settings.json` — a `job.yaml` schema glob, which does not exist yet.

**Optional upstream dependencies left unset**

Both of the following are env-gated in _both_ upstream entrypoints, so leaving them unset is configuration, not a design departure:

- **Redis.**
  `main.ts` pings Redis only `if (process.env.REDIS_URL)`, and the only other consumer is the Socket.IO redis-streams adapter for multi-replica fan-out, also gated on `REDIS_URL`.
  At one replica there is nothing for it to do.
  The cluster's `databases/valkey` is available the day a second replica is wanted.
- **S3.**
  With `S3_HOST` unset, `storage/files.ts` writes to `${DATA_DIR}/files` on local disk; that is what the PVC is for.
  When an S3 service lands in the cluster, moving uploads onto it is an env-only change (`S3_HOST`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PUBLIC_URL`) that retires the PVC and `strategy: Recreate`.

**Risks**

- **Silent fallback to the public server.**
  `getServerUrl()` in the web app ends its fallback chain at `DEFAULT_SERVER_URL = 'https://api.cluster-fluster.com'`.
  If `HAPPY_INJECT_HTML_CONFIG` is unset, the self-hosted web UI loads fine and quietly talks to the public server — upstream's own self-host plan names this "the worst possible failure mode: exfiltrates data the user thought was staying local."
  The deployment must fail loudly rather than degrade here.
- **Voice defaults to the public server even on a custom server.**
  `getVoiceServerUrl()` returns the public server unless the client's "use custom server for voice" toggle is on, so voice-token requests leak to the public service by default.
  This is a client-side default the relay cannot change; it is recorded, and the cutover checks the toggle.
- **An untested upstream combination.**
  Standalone entrypoint + `DB_PROVIDER=postgres` is sound by inspection — `createClient()` branches on that variable, the Prisma datasource is natively `postgresql`, and the package ships both the Prisma CLI and migrations — but upstream CI exercises standalone only with PGlite and Postgres only via the full `main.ts`.
  This has to be proven locally before any cluster work.
- **Open registration on a public hostname.**
  The server is multi-tenant and has no first-client lockout; upstream lists that as out of scope.
  Anyone who reaches `/v1/auth` can create an account, and the authentik gate on the UI does nothing to change that.
  Accounts are inert without a paired machine, but the exposure is real and is the accepted cost of off-LAN mobile access.
- **PVC deletion destroys data.**
  Per the cluster's storage contract, all classes are `reclaimPolicy: Delete` and there is no volsync.
  Losing the relay's PVC or CNPG volume loses session history.
- **Metrics are gated on an upstream release.**
  Until the `standalone.ts` change ships in a published `happy-server-self-host`, the image cannot serve `/metrics`; the task is sequenced so the rest of the deployment does not wait on it.

**Non-goals**

- Running agents, builds, or any development workload on cluster nodes.
  That is a separate workload with its own bootstrap problem (pairing is an interactive QR flow) and deserves its own change.
- Syncing repositories into the cluster.
  Nothing in Happy does this.
- Migrating _live_ daemon sessions.
  A daemon binds to one server, and repointing it restarts it; running sessions are finished or resumed through Claude Code's own local transcripts, not moved.
- GitHub account linking.
  Happy's "Connect GitHub" is profile decoration (username, avatar, a stored token upstream may use later) behind a full GitHub _App_ registration, and its OAuth callback redirects to a hardcoded `https://app.happy.engineering`, so it cannot complete against a self-hosted relay without patching.
  It stays unconfigured and the Settings entry is inert.
- ElevenLabs voice.
  Voice mode is ElevenLabs Conversational AI end to end — the relay mints tokens from a hardcoded `api.elevenlabs.io`, and the clients speak ElevenLabs' protocol through its SDK — so it is not a pluggable voice endpoint.
  It stays unconfigured; the client-side public-server default is handled under Risks.
- RevenueCat.
  Env-gated; stays unconfigured.
- Cilium network policies for the new pod.
  Lockdown here is opt-in per pod, and the cluster's policy contract forbids adding grants prophylactically.
  Happy's real egress set (Expo push, GitHub, ElevenLabs, RevenueCat) should be observed in audit mode first, in its own change.
- Deploying to `en.jm0.io`.
- A Prometheus scrape job.
  The relay exposes metrics; the prometheus changeset owns the `ServiceMonitor`.
