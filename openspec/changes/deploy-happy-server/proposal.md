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
The only plaintext it handles is service tokens (GitHub OAuth, vendor keys), encrypted at rest under a key tree derived from `HANDY_MASTER_SECRET`.

**Projects are never synced.**
A `Project` row on the server is an encrypted catalog entry — external id, metadata blob, data key, avatar — and its own source comment states the server "only indexes the caller-owned external id and stores/serves opaque values."
Actual code is reached live, on demand, by RPC over the session socket (`bash`, `readFile`, `writeFile`, `listDirectory`, `getDirectoryTree`, `ripgrep`, `difftastic`), and those responses are transient.
Source lives in exactly one place: the filesystem of whichever machine runs the `happy` daemon.

So this change buys **data sovereignty over session metadata**, not cluster-side compute.
Agents keep running on workstations.
Getting them onto cluster nodes would mean a second, unrelated workload — a pod running `happy daemon start-sync` against a PVC you populate yourself — which is deliberately **out of scope here** (see Non-goals).

## What Changes

- **New app `kubernetes/apps/home/happy/`** — an `app-template` HelmRelease running the relay, its `HTTPRoute` on `envoy-external`, a small `PVC` for uploaded assets, and an `ExternalSecret` for `HANDY_MASTER_SECRET`.
- **New `happy-db.ks.yaml`** attaching the existing `kubernetes/components/cnpg-database` component, giving the relay its own CNPG cluster and credentials.
- **New `containers/` root tree** holding a thin `Dockerfile` over the published `happy-server-self-host` npm package, plus a GitHub Actions workflow that builds and pushes it to `ghcr.io`.
  Upstream publishes no container image, so this is the repository's first container build.
- **Migrations run as a Flux-gated step**, not at container start, because the external-Postgres path needs `prisma migrate deploy` rather than the PGlite-only migrator baked into the package's `happy-server migrate`.
- **The relay serves its own web UI** at the same origin, with `HAPPY_INJECT_HTML_CONFIG` set explicitly — see Impact for why that is load-bearing rather than cosmetic.
- **No authentik integration.**
  Happy's CLI, mobile, and desktop clients are not browsers and cannot complete an outpost redirect; the app's own signed- challenge public-key auth is the gate.
  This is a deliberate departure from the house pattern and is recorded as such.

## Capabilities

### New Capabilities

- `happy-relay`: the self-hosted Happy sync relay as a cluster service — what it stores and what it refuses to store, its persistence and exposure contract, the client-origin binding that keeps self-hosted clients off the public server, and the boundary between the relay and agent execution.

### Modified Capabilities

- `repo-layout`: the root-tree contract enumerates the tool-specific trees allowed directly under the repository root.
  This change adds `containers/` as a new one, so the requirement's enumeration must grow to cover it.

## Impact

**Affected systems**

- `kubernetes/apps/home/` — gains a `happy/` app directory and must list it in the namespace's per-app selection.
- `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml` — selects the new app.
  `en.jm0.io` is deliberately not wired up.
- `cloudnative-pg` (namespace `databases`) and `onepassword-connect` (namespace `external-secrets`) become `dependsOn` edges.
- 1Password vault `Homelab` — a new item holding the master secret.
- `ghcr.io` — a new package under the repo owner.

**Dependencies this deliberately avoids**

- **No Redis/valkey.**
  The standalone entrypoint's `startServer` never touches Redis; only the full `main.ts` production entrypoint pings it at boot.
  Using the standalone entrypoint with an external Postgres drops the dependency entirely.
- **No S3/MinIO.**
  With `S3_HOST` unset, the server falls back to local filesystem storage under `${DATA_DIR}/files`.
  The cluster has no S3 service, and adding one for avatars would be absurd.
  This is what the PVC is for.

**Risks**

- **Silent fallback to the public server.**
  `getServerUrl()` in the web app ends its fallback chain at `DEFAULT_SERVER_URL = 'https://api.cluster-fluster.com'`.
  If `HAPPY_INJECT_HTML_CONFIG` is unset, the self-hosted web UI loads fine and quietly talks to the public server — upstream's own self-host plan names this "the worst possible failure mode: exfiltrates data the user thought was staying local."
  The deployment must fail loudly rather than degrade here.
- **An untested upstream combination.**
  Standalone entrypoint + `DB_PROVIDER=postgres` is sound by inspection — `createClient()` branches on that variable, the Prisma datasource is natively `postgresql`, and the package ships both the Prisma CLI and migrations — but upstream CI exercises standalone only with PGlite and Postgres only via the full `main.ts`.
  This has to be proven locally before any cluster work.
- **Open registration on a public hostname.**
  The server is multi-tenant and has no first-client lockout; upstream lists that as out of scope.
  Anyone who reaches `/v1/auth` can create an account.
  Accounts are inert without a paired machine, but the exposure is real and is the accepted cost of off-LAN mobile access.
- **PVC deletion destroys data.**
  Per the cluster's storage contract, all classes are `reclaimPolicy: Delete` and there is no volsync.
  Losing the relay's PVC or CNPG volume loses session history.

**Non-goals**

- Running agents, builds, or any development workload on cluster nodes.
  That is a separate workload with its own bootstrap problem (pairing is an interactive QR flow) and deserves its own change.
- Syncing repositories into the cluster.
  Nothing in Happy does this.
- Migrating existing session history off the public server.
  There is no export path; this is a clean start.
- Cilium network policies for the new pod.
  Lockdown here is opt-in per pod, and the cluster's policy contract forbids adding grants prophylactically.
  Happy's real egress set (Expo push, GitHub, ElevenLabs, RevenueCat) should be observed in audit mode first, in its own change.
- Deploying to `en.jm0.io`.
