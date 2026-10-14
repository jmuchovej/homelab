## 1. Prove the untested combination first

- [ ] 1.1 Install `happy-server-self-host@1.1.11` into a scratch directory and confirm its `postinstall` `prisma generate` succeeds and emits a query engine for `linux-x64`; verify by listing the generated client directory
- [ ] 1.2 Start a throwaway Postgres (container or `devenv`), run `prisma migrate deploy --schema=<pkg>/prisma/schema.prisma` against it, and verify the `_prisma_migrations` table lists every shipped migration as finished
- [ ] 1.3 Run the package's `happy-server serve` with `DB_PROVIDER=postgres`, `DATABASE_URL`, `HANDY_MASTER_SECRET`, and `DATA_DIR` set; verify `GET /health` returns healthy and that nothing dials 6379 (Redis is `REDIS_URL`-gated and the variable is unset)
- [ ] 1.4 Confirm the Postgres path is genuinely in use — query the throwaway database for the `Account` table and verify a `POST /v1/auth` challenge creates a row there, not in any local PGlite directory
- [ ] 1.5 Record the outcome in design.md D2. **If 1.3 or 1.4 fails, stop and revisit D2** (fallback: PGlite on a PVC) before writing any manifest

## 2. Upstream metrics flag (design D9)

- [ ] 2.1 In the `slopus/happy` checkout, make `standalone.ts serve()` call `startMetricsServer()` when `METRICS_ENABLED=true` (opt-in; default behavior unchanged), run the server test suite, and open the PR
- [ ] 2.2 Verify locally against the throwaway Postgres: with `METRICS_ENABLED=true METRICS_PORT=9090`, `GET :9090/metrics` returns Prometheus text containing `http_requests_total`-style counters and Prisma metrics; without the variable, nothing listens on 9090
- [ ] 2.3 Once a `happy-server-self-host` release carries the change, record its version for the Dockerfile pin in 3.1; until then, the rest of §3–§7 proceeds on `1.1.11` and the metrics acceptance in 7.10 stays open

## 3. Container image

- [ ] 3.1 Create `kubernetes/containers/happy-server/Dockerfile` — `node:22-slim`, exact-pinned `npm install -g happy-server-self-host@<version>`, non-root runtime user, `WORKDIR`/`DATA_DIR` on a writable path, `EXPOSE 3005 9090`; verify `docker build` succeeds with that directory as the only context
- [ ] 3.2 Run the built image locally against the throwaway Postgres from §1 and verify `/health` returns healthy, reproducing 1.3 inside the container
- [ ] 3.3 Verify the image serves the bundled web app — fetch `/` and confirm an HTML document with the Expo bundle is returned, not a 404
- [ ] 3.4 Verify origin injection — run the image with `HAPPY_INJECT_HTML_CONFIG` set, fetch `/`, and confirm the HTML contains `window.__HAPPY_CONFIG__` naming that origin; then run it _without_ the variable and confirm the injection is absent, documenting the fallback hazard this guards (design D4)
- [ ] 3.5 Add `.github/workflows/happy-server-image.yaml` building `linux/amd64` and pushing to `ghcr.io` on changes to `kubernetes/containers/happy-server/**`, using the `bjw-s-labs/action-changed-files` filter step the way `flux-local.yaml` does; verify by triggering it and confirming the package appears in the registry
- [ ] 3.6 Record the pushed image's digest for use in §5

## 4. Secrets and database

- [ ] 4.1 Create the 1Password item in vault `Homelab` holding the relay master secret (32 random bytes, base64); verify it is readable through the existing `onepassword-connect` store
- [ ] 4.2 Create `kubernetes/apps/local-ai/happy/happy-db.ks.yaml` attaching `./kubernetes/components/cnpg-database` with `APP: happy`, `DB_SIZE`, and `DB_LB_OCTET: "61"`, `targetNamespace: local-ai`, and `dependsOn` on `cloudnative-pg` (databases) and `onepassword-connect` (external-secrets); verify `kubectl kustomize --load-restrictor LoadRestrictionsNone` builds it
- [ ] 4.3 Confirm `61` is still free by grepping `DB_LB_OCTET` across `kubernetes/apps` before committing

## 5. Application manifests

- [ ] 5.1 Create `kubernetes/apps/local-ai/happy/app/oci-repository.yaml` pointing at the `app-template` chart at the same version other apps use; verify the version matches `chroma`'s
- [ ] 5.2 Create `kubernetes/apps/local-ai/happy/app/external-secret.yaml` projecting the master secret into a `happy-secrets` Secret; verify the `ExternalSecret` syncs with status `SecretSynced`
- [ ] 5.3 Create `kubernetes/apps/local-ai/happy/app/pvc.yaml` — RWO, `zfs-ssd`, small, for `DATA_DIR` uploaded assets (design D7); verify it binds
- [ ] 5.4 Create `kubernetes/apps/local-ai/happy/app/helm-release.yaml` — single replica, `strategy: Recreate`, image pinned to the tag-plus-digest from 3.6, env for `DB_PROVIDER=postgres`, `DATABASE_URL` from the CNPG creds secret, `HANDY_MASTER_SECRET` from `happy-secrets`, `DATA_DIR`, `PORT`, `HOST`, `PUBLIC_URL`, `HAPPY_INJECT_HTML_CONFIG`, `METRICS_ENABLED=true`, `METRICS_PORT=9090`; Service ports `http` (3005) and `metrics` (9090); liveness/readiness/startup probes on `/health`; verify the rendered manifest sets every one of those variables and both ports
- [ ] 5.5 Add the migration `Job` as `kubernetes/apps/local-ai/happy/app/job.yaml` running `prisma migrate deploy` from the same image and digest, and verify it is ordered ahead of the Deployment (design D3) — either as its own `happy-db-migrate.ks.yaml` that the app ks `dependsOn`, or via a Flux-respected ordering annotation; whichever is chosen, verify a deliberately failing migration leaves the previous Deployment serving
- [ ] 5.6 Create `kubernetes/apps/local-ai/happy/app/http-route.yaml` with three raw routes on `happy.${DC_DOMAIN}` / `envoy-external` (design D5): `happy` (`PathPrefix /`, labelled `authentik.rbn/enabled: "true"` with `authentik.rbn/name|group|icon|access` annotations), `happy-api` (`PathPrefix` `/v1`, `/v2`, `/v3`, `/socket.io`, `/files`, `/health`; no labels), and `happy-outpost` (`/outpost.goauthentik.io` → `${AK_OUTPOST_PROXY}`); verify with `kubectl kustomize` that only `happy` carries the label
- [ ] 5.7 Create `kubernetes/apps/local-ai/happy/app/security-policy.yaml` targeting **only** the `happy` route, copied from the `linkding` shape; verify its single `targetRef` is `happy`
- [ ] 5.8 Create `kubernetes/apps/local-ai/happy/app/kustomization.yaml` listing every resource, and `kubernetes/apps/local-ai/happy/happy.ks.yaml` with `dependsOn` on `happy-db`, `envoy-config` (network), and `onepassword-connect` (external-secrets); verify with `kubectl kustomize --load-restrictor LoadRestrictionsNone`
- [ ] 5.9 Create the namespace-stamped wrapper `kubernetes/apps/local-ai/happy/kustomization.yaml` following the `chroma` shape; verify it sets `namespace: local-ai`

## 6. Wire up and reconcile

- [ ] 6.1 Add `../../../apps/local-ai/happy` to the `local-ai` block of `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml`, leaving `en.jm0.io` untouched; verify `en`'s selection is unchanged by diffing it
- [ ] 6.2 Add a `batch/job_v1.json` glob for `./kubernetes/**/job.yaml` to `.zed/settings.json` (none exists; `http-route`, `security-policy`, `pvc`, `external-secret`, `helm-release`, and `*.ks.yaml` are already covered); verify the schema URL resolves with `curl -sI`
- [ ] 6.3 Run `nix fmt` and the repo's pre-commit hooks; verify formatting and schema checks pass
- [ ] 6.4 Reconcile and verify all Flux Kustomizations (`happy-db`, the migration step, `happy`) reach `Ready`
- [ ] 6.5 Verify the CNPG cluster is healthy and the relay pod is running with its PVC bound
- [ ] 6.6 Run `just tofu::plan` and verify the discovered `happy` route produces exactly one new authentik proxy provider and application; apply

## 7. Acceptance against the spec

- [ ] 7.1 Verify TLS and reachability — `curl https://happy.${DC_DOMAIN}/health` from off-LAN, with no cookie, returns healthy (spec: API paths carry no identity-provider gate)
- [ ] 7.2 **Verify the UI gate** — `curl -I https://happy.${DC_DOMAIN}/` with no cookie returns a redirect into authentik; after signing in, the page loads and devtools shows its `/v1` and `/socket.io` calls succeeding with no further outpost round-trips (spec: web client gated; authenticated browser reaches a working client)
- [ ] 7.3 **Verify the API bypasses the gate** — with no cookie, `GET /v1/version` returns 200 and a raw Socket.IO handshake (`GET /socket.io/?EIO=4&transport=polling`) is answered by the relay, not redirected (spec: API paths carry no identity-provider gate)
- [ ] 7.4 **Verify origin binding** — fetch `https://happy.${DC_DOMAIN}/` and assert the HTML carries `window.__HAPPY_CONFIG__` with `serverUrl` equal to that hostname and `disableAnalytics: true`; then load the page in a browser with devtools open and confirm zero requests to `api.cluster-fluster.com` (spec: self-hosted clients bind to the relay's own origin)
- [ ] 7.5 Pair a workstation `happy` CLI daemon against the relay with no browser step, and verify the machine appears in the web UI (spec: CLI daemon authenticates directly)
- [ ] 7.6 Run one real agent session end-to-end from the web UI against the paired workstation, and verify output streams back
- [ ] 7.7 **Verify the relay holds no source** — inspect the relay's Postgres and its PVC after 7.6 and confirm no file contents from the session's project are present, only encrypted blobs (spec: the relay holds no source code)
- [ ] 7.8 **Verify no model-provider traffic from the relay** — while a session is active, confirm the relay pod opens no connection to any model provider endpoint (spec: no model-provider traffic originates from the relay)
- [ ] 7.9 Verify persistence across replacement — delete the relay pod, wait for reschedule, and confirm sessions, machines, and message history are intact and an uploaded avatar still serves (spec: state survives a rollout, uploaded assets outlive the pod)
- [ ] 7.10 **Verify metrics** — from an in-cluster pod, `GET http://happy.local-ai.svc:9090/metrics` returns Prometheus text; `GET https://happy.${DC_DOMAIN}/metrics` is not served by the metrics listener (spec: metrics served on a dedicated in-cluster port).
      Blocked until 2.3 moves the pin
- [ ] 7.11 Verify the relay refuses to start without its master secret, rather than generating one (spec: master secret is supplied by the deployment)
- [ ] 7.12 Pair the mobile client from outside the LAN and verify its realtime connection establishes (spec: mobile client connects from outside the LAN)
- [ ] 7.13 Verify the voice default — on a client bound to the relay with "use custom server for voice" off, confirm a voice-token request targets the public service; turn the setting on and confirm it targets the relay (spec: voice server default is a recorded exposure)

## 8. History migration (design D11)

- [ ] 8.1 Write the one-shot copy script (TypeScript under `bun`, kept outside the repo's tooling surface — `.scratch/` or the change directory, deleted at archive) that authenticates to source and destination with `~/.happy/access.key` and copies machines → projects → sessions → messages → kv → profile, reading via `/v2/sessions` and `/v3/sessions/:id/messages` with pagination, writing via `POST /v1/machines`, `/v1/projects`, `/v1/sessions`, `/v3/sessions/:id/messages`, `/v1/kv/bulk`, and emitting an old→new session id map
- [ ] 8.2 Dry-run against the throwaway Postgres from §1 as destination and the public service as source; verify session, message, and machine counts match, and that re-running the script changes nothing (spec: re-running the copy duplicates nothing)
- [ ] 8.3 Stop the workstation daemon; run the script against the relay; verify counts again and open one migrated session in the web UI with its full history in order (spec: copied history is intact and ordered)
- [ ] 8.4 Rewrite the session ids in `~/.happy/sessions.json` through the id map; verify `happy resume <new-id>` attaches to the copied session on the relay (spec: resume follows the moved history)
- [ ] 8.5 Repoint the CLI, web, and mobile clients per the design's Migration Plan, enabling "use custom server for voice" on each; verify the public-service account is untouched as the rollback path
- [ ] 8.6 Delete the script and its credentials material once 8.3–8.5 are verified

## 9. Documentation

- [ ] 9.1 Sweep every comment added to the new manifests against the repo's load-bearing test, lifting non-load-bearing context into `kubernetes/AGENTS.md`; verify no rationale-only comments remain in the YAML
- [ ] 9.2 Record in `kubernetes/AGENTS.md` the facts a future edit would otherwise violate: why the hostname is split into a gated UI route and an ungated API route (and that `/files` must stay on the API route), why `HAPPY_INJECT_HTML_CONFIG` is mandatory, why `METRICS_ENABLED` is opt-in and the metrics port is not routed, and that the relay runs no agent workload
- [ ] 9.3 Add `containers/` to the Layout block in `kubernetes/AGENTS.md` with the image-build contract (self-contained context, published to `ghcr.io`, consumed by tag-plus-digest, path filter per image workflow); verify the existing `kubernetes/**` rule glob covers the new directory and that no new `.agents/rules` link is needed
- [ ] 9.4 Note two pre-existing items, do not fix them here: `.github/workflows/flux-local.yaml`'s `--path kubernetes/flux/cluster` predates the per-cluster layout, and its `kubernetes/**/*` filter now also fires on Dockerfile edits
