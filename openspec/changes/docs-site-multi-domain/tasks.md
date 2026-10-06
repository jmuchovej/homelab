## 1. Toolchain and dependencies

- [ ] 1.1 Confirm `bun` is on the devshell PATH (`which bun` inside `devenv shell`); if absent, add it to `modules/devshell/shells.nix` and verify `bun --version` prints inside the shell
- [ ] 1.2 In `docs/`, add `wrangler` as a dev dependency (`just docs add -d wrangler`) and verify `bun run wrangler --version` prints and `bun.lock` changed
- [ ] 1.3 Add `mod docs "docs/justfile"` to the root justfile; verify `just --list` shows the `docs` module and `just docs::build` runs the existing build recipe

## 2. Host resolution and allowlist (shared)

- [ ] 2.1 Create `docs/shared/utils/site.ts` exporting `resolveSite(hostname)` (first label `holonet` → `holonet`, else `rebellion`), a `SITES` table with each site's landing path (`/rebellion`, `/holonet`) and holonet's allowed prefixes (`/`, `/network`), the framework asset prefixes from design D3, and an `isAllowed(site, path)` helper; verify with a small `vitest` file under `docs/test/` that `holonet.jm0.io`, `holonet.localhost`, `jm0.io`, and `localhost` resolve as expected and that `/network/x`, `/`, `/_nuxt/a.js` pass while `/reference`, `/.well-known/webfinger`, `/sitemap.xml`, `/llms.txt` fail on holonet
- [ ] 2.2 Create `docs/server/middleware/site.ts` that sets `event.context.site` from the request host and throws a 404 on holonet for any path `isAllowed` rejects; verify under `nuxi dev` that `curl -H 'Host: holonet.localhost' localhost:3000/reference` returns 404 and `/network` returns 200
- [ ] 2.3 Create `docs/app/middleware/site.global.ts` that applies `isAllowed` to client-side navigation (`abortNavigation` with a 404 error) and redirects `/rebellion` and `/holonet` to `/` on their owning host with a 301 (external for the other host); verify in the browser that clicking a link to `/reference` on `holonet.localhost:3000` shows the 404 page without rendering, and that `localhost:3000/holonet` lands on `holonet.localhost:3000/`

## 3. Landing pages

- [ ] 3.1 Rename `docs/content/index.md` to `docs/content/rebellion.md` and add `navigation: false` to its frontmatter; verify `nuxi dev` no longer lists it in the header navigation and `queryCollection('docs').path('/rebellion')` returns it (via the Nuxt Content devtools or a temporary log)
- [ ] 3.2 Create `docs/content/holonet.md` with `navigation: false`, a hero for the network site, and links into `/network`; verify it renders at `/holonet` under `nuxi dev` before the redirect from 2.3 is in place, or with the redirect temporarily disabled
- [ ] 3.3 Fetch Docus's `layer/app/templates/landing.vue` for the installed `docus` version (`docs/node_modules/docus/app/templates/landing.vue`) and create `docs/app/pages/index.vue` that resolves the site with `useRequestURL().hostname`, queries `docs` for `SITES[site].landing`, and renders it the way the template does; verify `curl localhost:3000/` and `curl -H 'Host: holonet.localhost' localhost:3000/` return different landing HTML with status 200 and no redirect
- [ ] 3.4 Confirm that adding `app/pages/index.vue` removed Docus's `landing` collection and `/` route without errors (`nuxi build` succeeds and `.nuxt/content/` lists only the `docs` collection)

## 4. Navigation and search filtering

- [ ] 4.1 Create `docs/app/composables/useSiteNavigation.ts` that returns the injected navigation filtered by `isAllowed` for the current site and with the two landing paths removed; verify by unit test that a tree containing `reference`, `guides`, `network` yields only `network` on holonet and all three on rebellion
- [ ] 4.2 Update `AppHeaderBody.vue`, `DocsAsideLeftBody.vue`, and `DocsAsideMobileBar.vue` to use the filtered tree and to call `useSubNavigation(filtered)` with it; verify in the browser that the header and sidebar on `holonet.localhost:3000/network` show only the `network` section while `localhost:3000/network` shows every section
- [ ] 4.3 Copy Docus's `AppSearch.vue` into `docs/app/components/app/AppSearch.vue` and filter `files` and `navigation` through the same helper; verify that searching on `holonet.localhost` for a term found only in `reference` (e.g. an aspect name) returns nothing while the same search on `localhost` finds it

## 5. `.well-known` endpoints

- [ ] 5.1 Move the issuer URL in `webfinger.ts` to `runtimeConfig.public.oidcIssuer` (default `https://id.jm0.io/application/o/tailscale/`, env `NUXT_PUBLIC_OIDC_ISSUER`) and add the holonet 404 guard; verify `curl 'localhost:3000/.well-known/webfinger?resource=acct:x@jm0.io'` returns the JRD with the same `subject` and link as before, `acct:x@example.com` returns 404, no `resource` returns 400, and the holonet host returns 404
- [ ] 5.2 Implement `atproto-did.ts` returning `runtimeConfig.public.atprotoDid` (default `did:plc:wjsziyvr5xuqyzykxp7eydg7`, env `NUXT_PUBLIC_ATPROTO_DID`) as `text/plain`; verify `curl localhost:3000/.well-known/atproto-did` prints exactly that DID and the holonet host returns 404

## 6. Network section

- [ ] 6.1 Create `docs/content/4.network/.navigation.yml` and `1.index.md` describing the section (sites, VLANs, holonet mesh, relays, DNS) and naming `mikrotik/NETWORK-REFERENCE.md` as the source to port; verify it appears last in the root site's navigation and is the only section on the network site

## 7. Cloudflare Workers build

- [ ] 7.1 In `docs/nuxt.config.ts` set `nitro.preset: 'cloudflare_module'`, `nitro.prerender.crawlLinks: false`, an app-level `nitro:config` hook that empties `prerender.routes`, `$production.content.database = { type: 'd1', bindingName: 'DB' }`, and the two `runtimeConfig.public` defaults from section 5; verify `nuxi dev` still runs on the native SQLite connector
- [ ] 7.2 Create `docs/wrangler.jsonc` with `name: rbn-docs`, `main: .output/server/index.mjs`, `assets: { directory: .output/public, binding: ASSETS }`, `compatibility_date`, `compatibility_flags: ["nodejs_compat"]`, a `d1_databases` entry bound as `DB` with a placeholder id, and no `routes`; verify `bun run wrangler deploy --dry-run --outdir /tmp/rbn-docs` succeeds after a build
- [ ] 7.3 Run `just docs::build` and verify `.output/public` contains no `index.html` for `/`, `/reference`, or any other content path (`find docs/.output/public -name 'index.html'` prints nothing)
- [ ] 7.4 Add `preview` (`nuxi build` then `wrangler dev`) and `deploy` (`wrangler deploy`) recipes to `docs/justfile`; verify `just docs::preview` serves `/` and that the first request populates the local D1 (a second request is faster and the wrangler log shows no SQL import)
- [ ] 7.5 Under `just docs::preview`, verify the full host matrix: `curl -H 'Host: holonet.localhost' .../` renders the network landing, `/reference` on that host is 404, `/network` is 200, `/.well-known/webfinger?resource=acct:x@jm0.io` on the default host returns the JRD and on holonet returns 404, and `/.well-known/atproto-did` prints the DID
- [ ] 7.6 Under `just docs::preview`, inspect the `<link rel="canonical">` and sitemap URLs on both hosts; if the network site's canonical names the root host, set the site URL per request in a plugin and re-verify

## 8. OpenTofu: D1 and custom domains

- [ ] 8.1 List the zone's existing DNS records for `jm0.io` (apex) and `holonet.jm0.io` (`just tofu::plan` plus the Cloudflare dashboard); record any record that OpenTofu does not manage and remove it before 8.3, verifying the plan afterwards shows no record at either name
- [ ] 8.2 Create `tofu/cf.docs.tofu` with `cloudflare_d1_database.docs` (`rbn-docs`, `primary_location_hint = "enam"`) and `cloudflare_workers_custom_domain.docs` for `local.domain.root` and `local.domain.holo` with `service = "rbn-docs"`; verify `just tofu::plan` shows exactly three creates and nothing else
- [ ] 8.3 After the Worker exists (9.3), run `just tofu::apply`, paste the D1 id into `wrangler.jsonc`, and verify a second `just tofu::plan` is a no-op

## 9. CI deploy

- [ ] 9.1 Rewrite `.github/workflows/docs.yml`: trigger on push to `main` with `paths: [docs/**]`, drop the Pages permissions and steps, `bun install --frozen-lockfile`, `bun run nuxi build`, `cloudflare/wrangler-action` with `workingDirectory: docs` and `command: deploy`, then `curl --fail` of `https://jm0.io/`, `https://holonet.jm0.io/`, and the WebFinger URL; verify the workflow file passes `actionlint` (`, actionlint`)
- [ ] 9.2 Set `CLOUDFLARE_API_TOKEN` (Workers Scripts: Edit, D1: Edit, account-scoped) and `CLOUDFLARE_ACCOUNT_ID` as repository secrets; verify they appear under the repository's Actions secrets
- [ ] 9.3 First deploy by hand with `just docs::deploy` so the `rbn-docs` Worker exists before 8.3; verify the Worker appears in the dashboard and its `workers.dev` URL (if enabled) renders the root landing
- [ ] 9.4 Redeploy after 8.3 (by hand or by merging) and verify from outside the LAN: `https://jm0.io/` and `https://holonet.jm0.io/` serve different landings with valid certificates, `https://holonet.jm0.io/reference` is 404, `https://jm0.io/.well-known/webfinger?resource=acct:x@jm0.io` returns the JRD, and `https://jm0.io/.well-known/atproto-did` prints the DID
- [ ] 9.5 Remove the GitHub Pages site in the repository settings and verify a push touching only `modules/` does not trigger the docs workflow

## 10. Rule file and cleanup

- [ ] 10.1 Write `docs/AGENTS.md` (`paths: ["docs/**"]`) covering the two-site model, where the allowlist lives, the no-prerender rule and why, the three Cloudflare-aware files, the OpenTofu ownership split and the Worker-before-custom-domain ordering, and the `dev`/`preview`/`deploy` recipes; link it as `.agents/rules/docs.md`, `jj file track` both, and verify the glob matches by opening a file under `docs/` in an agent session
- [ ] 10.2 Sweep comments added during implementation per the repo's comment policy, run `nix fmt`, and verify `jj diff --stat` shows only files named in this change
