## 1. Prove the untested combination first

- [ ] 1.1 Install `happy-server-self-host@1.1.11` into a scratch directory and confirm its `postinstall` `prisma generate` succeeds and emits a query engine for `linux-x64`; verify by listing the generated client directory
- [ ] 1.2 Start a throwaway Postgres (container or `devenv`), run `prisma migrate deploy --schema=<pkg>/prisma/schema.prisma` against it, and verify the `_prisma_migrations` table lists every shipped migration as finished
- [ ] 1.3 Run the package's `happy-server serve` with `DB_PROVIDER=postgres`, `DATABASE_URL`, `HANDY_MASTER_SECRET`, and `DATA_DIR` set; verify `GET /health` returns healthy and that no Redis connection is attempted (check logs and confirm nothing listens for or dials 6379)
- [ ] 1.4 Confirm the Postgres path is genuinely in use — query the throwaway database for the `Account` table and verify a `POST /v1/auth` challenge creates a row there, not in any local PGlite directory
- [ ] 1.5 Record the outcome in design.md D2. **If 1.3 or 1.4 fails, stop and revisit D2** (fallback: PGlite on a PVC) before writing any manifest

## 2. Container image

- [ ] 2.1 Create `containers/happy-server/Dockerfile` — `node:22-slim`, exact-pinned `npm install -g happy-server-self-host@1.1.11`, non-root runtime user, `WORKDIR`/`DATA_DIR` on a writable path; verify `docker build` succeeds
- [ ] 2.2 Run the built image locally against the throwaway Postgres from task 1 and verify `/health` returns healthy, reproducing 1.3 inside the container
- [ ] 2.3 Verify the image serves the bundled web app — fetch `/` and confirm an HTML document with the Expo bundle is returned, not a 404
- [ ] 2.4 Verify origin injection — run the image with `HAPPY_INJECT_HTML_CONFIG` set, fetch `/`, and confirm the HTML contains `window.__HAPPY_CONFIG__` naming that origin; then run it _without_ the variable and confirm the injection is absent, documenting the fallback hazard this guards (design D4)
- [ ] 2.5 Add `.github/workflows/happy-server-image.yaml` building `linux/amd64` and pushing to `ghcr.io` on changes to `containers/happy-server/**`, with a path filter matching the `flux-local.yaml` convention; verify by triggering it and confirming the package appears in the registry
- [ ] 2.6 Record the pushed image's digest for use in task 4

## 3. Secrets and database

- [ ] 3.1 Create the 1Password item in vault `Homelab` holding the relay master secret (32 random bytes, base64); verify it is readable through the existing `onepassword-connect` store
- [ ] 3.2 Create `kubernetes/apps/home/happy/happy-db.ks.yaml` attaching `./kubernetes/components/cnpg-database` with `APP: happy`, `DB_SIZE`, and `DB_LB_OCTET: "61"`, `targetNamespace: home`, and `dependsOn` on `cloudnative-pg` (databases) and `onepassword-connect` (external-secrets); verify `kubectl kustomize --load-restrictor LoadRestrictionsNone` builds it
- [ ] 3.3 Confirm `61` is still free by grepping `DB_LB_OCTET` across `kubernetes/apps` before committing

## 4. Application manifests

- [ ] 4.1 Create `kubernetes/apps/home/happy/app/oci-repository.yaml` pointing at the `app-template` chart at the same version other `home` apps use; verify the version matches `linkding`'s
- [ ] 4.2 Create `kubernetes/apps/home/happy/app/external-secret.yaml` projecting the master secret into a `happy-secrets` Secret; verify the `ExternalSecret` syncs with status `SecretSynced`
- [ ] 4.3 Create `kubernetes/apps/home/happy/app/pvc.yaml` — RWO, `zfs-ssd`, small, for `DATA_DIR` uploaded assets (design D7); verify it binds
- [ ] 4.4 Create `kubernetes/apps/home/happy/app/helm-release.yaml` — single replica, `strategy: Recreate`, image pinned to the tag-plus-digest from 2.6, env for `DB_PROVIDER=postgres`, `DATABASE_URL` from the CNPG creds secret, `HANDY_MASTER_SECRET` from `happy-secrets`, `DATA_DIR`, `PORT`, `HOST`, `PUBLIC_URL`, and `HAPPY_INJECT_HTML_CONFIG`; liveness/readiness/startup probes on `/health`; verify the rendered manifest sets every one of those variables
- [ ] 4.5 Add the migration `Job` to the app tree running `prisma migrate deploy` from the same image and digest, and verify it is ordered ahead of the Deployment (design D3) — either as its own `happy-db-migrate.ks.yaml` that the app ks `dependsOn`, or via a Flux-respected ordering annotation; whichever is chosen, verify a deliberately failing migration leaves the previous Deployment serving
- [ ] 4.6 Create `kubernetes/apps/home/happy/app/http-route.yaml` — `envoy-external` parentRef, hostname `happy.${DC_DOMAIN}`, **no** `authentik.rbn/enabled` label and no `SecurityPolicy` (design D5); verify no `SecurityPolicy` exists in the tree
- [ ] 4.7 Create `kubernetes/apps/home/happy/app/kustomization.yaml` listing every resource, and `kubernetes/apps/home/happy/happy.ks.yaml` with `dependsOn` on `happy-db`, `envoy-config` (network), and `onepassword-connect` (external-secrets); verify with `kubectl kustomize --load-restrictor LoadRestrictionsNone`
- [ ] 4.8 Create the namespace-stamped wrapper `kubernetes/apps/home/happy/kustomization.yaml` following the `linkding` shape; verify it sets `namespace: home`

## 5. Wire up and reconcile

- [ ] 5.1 Add `../../../apps/home/happy` to `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml`, leaving `en.jm0.io` untouched; verify `en`'s selection is unchanged by diffing it
- [ ] 5.2 Run `nix fmt` and the repo's pre-commit hooks; verify formatting and schema checks pass
- [ ] 5.3 Add the `happy.ks.yaml` / `helm-release.yaml` filename globs to `.zed/settings.json` only if the existing globs do not already cover them; verify by checking the current glob patterns first
- [ ] 5.4 Reconcile and verify all Flux Kustomizations (`happy-db`, the migration step, `happy`) reach `Ready`
- [ ] 5.5 Verify the CNPG cluster is healthy and the relay pod is running with its PVC bound

## 6. Acceptance against the spec

- [ ] 6.1 Verify TLS and reachability — `curl https://happy.${DC_DOMAIN}/health` from off-LAN returns healthy (spec: relay reachable by non-browser clients)
- [ ] 6.2 **Verify origin binding** — fetch `https://happy.${DC_DOMAIN}/` and assert the HTML carries `window.__HAPPY_CONFIG__` with `serverUrl` equal to that hostname and `disableAnalytics: true`; then load the page in a browser with devtools open and confirm zero requests to `api.cluster-fluster.com` (spec: self-hosted clients bind to the relay's own origin)
- [ ] 6.3 Pair a workstation `happy` CLI daemon against the relay with no browser step, and verify the machine appears in the web UI (spec: CLI daemon authenticates directly)
- [ ] 6.4 Run one real agent session end-to-end from the web UI against the paired workstation, and verify output streams back
- [ ] 6.5 **Verify the relay holds no source** — inspect the relay's Postgres and its PVC after 6.4 and confirm no file contents from the session's project are present, only encrypted blobs (spec: the relay holds no source code)
- [ ] 6.6 **Verify no model-provider traffic from the relay** — while a session is active, confirm the relay pod opens no connection to any model provider endpoint (spec: no model-provider traffic originates from the relay)
- [ ] 6.7 Verify persistence across replacement — delete the relay pod, wait for reschedule, and confirm sessions, machines, and message history are intact and an uploaded avatar still serves (spec: state survives a rollout, uploaded assets outlive the pod)
- [ ] 6.8 Verify the relay refuses to start without its master secret, rather than generating one (spec: master secret is supplied by the deployment)
- [ ] 6.9 Pair the mobile client from outside the LAN and verify its realtime connection establishes (spec: mobile client connects from outside the LAN)

## 7. Documentation

- [ ] 7.1 Sweep every comment added to the new manifests against the repo's load-bearing test, lifting non-load-bearing context into `kubernetes/AGENTS.md`; verify no rationale-only comments remain in the YAML
- [ ] 7.2 Record in `kubernetes/AGENTS.md` the facts a future edit would otherwise violate: why there is no `SecurityPolicy` on this route, why `HAPPY_INJECT_HTML_CONFIG` is mandatory, and that the relay runs no agent workload
- [ ] 7.3 Create `containers/AGENTS.md` with `paths: ["containers/**"]` frontmatter documenting the image-build contract, and add the relative symlink `.agents/rules/containers.md`; verify the glob resolves to real files and `jj file track` both
- [ ] 7.4 Note the pre-existing staleness in `.github/workflows/flux-local.yaml` (its `--path kubernetes/flux/cluster` predates the per-cluster layout) — report it, do not fix it here
