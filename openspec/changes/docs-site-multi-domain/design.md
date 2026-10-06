# Design

## Context

See `proposal.md` for motivation.
The facts that shape the approach:

- `docs/` extends the Docus layer (`docus@latest` on Nuxt 4, Nuxt Content 3, Nuxt UI 4).
  Docus registers a `/` page from its own `landing.vue` template **only when the app has no `app/pages/index.vue`**; when the app provides one, Docus also stops defining its `landing` content collection, and `content/index.md` belongs to no collection because the `docs` collection excludes it.
  That file is therefore the documented seam for a custom landing page, and the price is that the landing content has to live somewhere the `docs` collection can see.
- Docus's catch-all page (`[[lang]]/[...slug].vue`) renders any `docs` document at its content path with the docs layout.
  Its `app.vue` fetches the navigation tree once with `queryCollectionNavigation('docs')` and `provide`s it; the header body, left aside, mobile bar, and search all read that injected tree, and `useSubNavigation()` accepts an explicit tree as an argument.
  The repo already overrides `AppHeaderBody.vue`, `DocsAsideLeftBody.vue`, and `DocsAsideMobileBar.vue` with a custom `RbnContentNavigation`, so there is an existing place to put site filtering.
- Docus's `nuxt.config.ts` turns on `nitro.prerender.crawlLinks` and pushes `/` and `/openapi.json` into the prerender routes from a `nitro:config` hook.
  Any page that gets prerendered becomes a static asset.
- On Cloudflare Workers, static assets are served by the assets binding **before** the Worker runs.
  A prerendered `/reference/aspects` would therefore be served on `holonet.jm0.io` without ever reaching the host-aware middleware, and a prerendered `/` can only be one of the two landings.
- Nuxt Content on Workers has no filesystem SQLite; the documented runtime database is D1 bound as `DB`, declared under `nitro.cloudflare.wrangler.d1_databases` (or an equivalent `wrangler.jsonc`), with the content dump loaded into D1 on first use when its checksum differs from what the database holds.
- The OpenTofu root already holds the Cloudflare zone (`data.cloudflare_zone.domain`), `local.domain.{root,da,en,holo}`, and R2 usage, on provider `cloudflare/cloudflare` 5.20.
  `cloudflare_workers_custom_domain` and `cloudflare_d1_database` exist in that provider line.
  A Workers custom domain creates and owns the DNS record for its hostname; an existing record at that name makes the create fail.
- Tailscale reads the WebFinger JRD only during initial custom-OIDC setup, requires `subject` to be the `acct:` resource and the issuer `href` to match the issuer's `/.well-known/openid-configuration` exactly.
- The Bluesky DID for the account that will use `jm0.io` as its handle is already recorded as `did:plc:wjsziyvr5xuqyzykxp7eydg7` in `modules/users/john/john.nix`.
- `docs/justfile` exists (`dev`, `build`, `generate`, `add` over `bun run nuxi`) but is not loaded by the root justfile.
  The devshell is where `bun` would come from; whether it is already there is not confirmed.

## Goals / Non-Goals

**Goals:**

- One build artifact; host decides the site.
- The holonet allowlist is declared once and enforced in exactly two places: a server middleware and a global route middleware.
- Everything Cloudflare-specific is confined to `nuxt.config.ts` (preset, database adapter), `wrangler.jsonc`, `tofu/cf.docs.tofu`, and the workflow.
  `shared/`, `server/routes`, `server/middleware`, `app/` must not import anything from the Cloudflare runtime.
- A local preview that exercises the real production bundle, including the Worker runtime and a local D1, so the host split and `.well-known` routes are testable before deploy.

**Non-Goals:**

- Caching or edge-rendering optimisations.
  SSR against D1 on every request is fine for this traffic.
- Build-time OG images.
  Docus generates them only during prerender (`ogImage.zeroRuntime`), and prerender is off; accept their absence.
- Making the holonet subset a security boundary.
  The content query endpoint serves the same database on both hosts.

## Decisions

### D1. Host resolution lives in `shared/utils/site.ts`

One module exports `resolveSite(hostname): 'rebellion' | 'holonet'` and a `SITES` table: for each site, its landing content path (`/rebellion`, `/holonet`) and, for holonet, the allowed path prefixes.
Nuxt 4's `shared/utils/` is auto-imported into both the app and the Nitro server, so the server middleware, the route middleware, the landing page, the navigation filter, and the search override all read the same definition.
The rule is "first hostname label is `holonet`", not an exact hostname, so `holonet.localhost` and `holonet.jm0.io` behave alike and no per-environment configuration is needed.

In the app, the site is read with `useRequestURL().hostname`, which is the request's host during SSR and `window.location` on the client, so both sides agree.
On the server it is read from the h3 event's host header once, in the middleware, and stashed on `event.context.site` for the routes.

_Alternatives:_ a `NUXT_SITE` build-time flag with two builds (two deploys, two D1 populations, and nothing to stop a holonet build from serving the wrong content if the domain were pointed wrongly); a Cloudflare-side rewrite of `/` to `/holonet` (hydration mismatch, since the client router sees `/` while the server rendered `/holonet`); a `nuxt-multi-tenancy`-style module (route-directory tenants, far more machinery than two sites need).

### D2. Landing pages are hidden `docs` documents; the app's `index.vue` picks one by site

`content/index.md` is renamed to `content/rebellion.md` and `content/holonet.md` is added, both with `navigation: false`.
Because they are ordinary `docs` documents, no collection override is needed and Docus's catch-all would render them at `/rebellion` and `/holonet`; the route middleware intercepts those two paths and redirects to the owning host's `/` (the same host for its own landing, so `/rebellion` on `jm0.io` is a 301 to `/`).
`app/pages/index.vue` resolves the site, queries `docs` for that site's landing path, and renders it with Docus's landing look (modelled on the layer's `app/templates/landing.vue`, fetched at implementation time, not reimplemented from memory).

_Alternative:_ a separate `landing` collection declared in an app-level `content.config.ts`.
It would keep landing files out of the `docs` collection, but whether an app-level collection named `docs` can override the layer's and exclude `landing/**` is undocumented, and without that override the files would be in both collections anyway.
Two hidden documents plus two redirects is boring and relies only on documented behaviour.

### D3. The holonet allowlist is enforced server-side and client-side from one table

`server/middleware/site.ts` runs for every request.
On holonet, it 404s any path that is not `/`, under `/network`, or under a short list of framework prefixes the page needs (`/_nuxt`, `/__nuxt_content`, `/__og-image__`, `/_fonts`, `/_ipx`, `/favicon.ico`, `/robots.txt`).
Everything else, including `/.well-known/*`, `/sitemap.xml`, `/llms*.txt`, `/openapi.json`, and `/api/*`, falls through to the 404.
`app/middleware/site.global.ts` applies the same table to client-side navigation with `abortNavigation` on a 404 error, and performs the landing-path redirects from D2 with `navigateTo(..., { external: true, redirectCode: 301 })`.

The content query endpoint (`/__nuxt_content/docs/query`) is deliberately allowed, because the page needs it and because restricting it would require inspecting SQL.
This is the "presentation, not disclosure" line the spec draws.

### D4. Navigation and search are filtered by site in the existing overrides

A `useSiteNavigation()` composable takes the injected navigation tree and, on holonet, keeps only top-level items whose path is allowlisted.
The three existing overrides use it and pass the filtered tree into `useSubNavigation(filtered)` instead of calling it without an argument.
`AppSearch.vue` is added as a fourth override: a copy of Docus's with the `files` (search sections) and `navigation` props filtered by the same table.

Landing documents are hidden from navigation by `navigation: false` and from search by filtering out the two landing paths in the same place.

### D5. Hosting is a Cloudflare Worker with D1; prerendering is off

- `nitro.preset = 'cloudflare_module'`; `nitro.prerender.crawlLinks = false` and an app-level `nitro:config` hook that empties `prerender.routes` after Docus's hook has pushed into it.
  The build is verified by checking that `.output/public` contains no `index.html` for any content path.
- `content.database = { type: 'd1', bindingName: 'DB' }` under the `$production` config key only, so `nuxi dev` keeps the native SQLite connector Docus configures.
- `wrangler.jsonc` is checked in and is the single source of Worker configuration: `name = "rbn-docs"`, `main = ".output/server/index.mjs"`, `assets = { directory: ".output/public", binding: "ASSETS" }`, `compatibility_flags = ["nodejs_compat"]`, the `d1_databases` binding with the database id from OpenTofu, and **no `routes`** (see D6).
  Nitro's `cloudflare.deployConfig` stays off so there is one config, not two.
- `wrangler` is a `docs/` dev dependency; `just docs::preview` runs `nuxi build` then `wrangler dev`, which emulates the Worker and a local D1 that Content populates on first request.

_Alternatives:_ in-cluster behind a tunnel (deferred by the proposal); GitHub Pages static (cannot run the routes, cannot split `/` by host); Cloudflare Pages (same runtime, but Pages Functions and custom-domain handling differ and Workers is where Cloudflare is investing).

### D6. OpenTofu owns the D1 database and both hostname bindings; wrangler owns only the script

`tofu/cf.docs.tofu`:

```hcl
resource "cloudflare_d1_database" "docs" {
  account_id            = data.cloudflare_zone.domain.account.id
  name                  = "rbn-docs"
  primary_location_hint = "enam"
}

resource "cloudflare_workers_custom_domain" "docs" {
  for_each   = toset([local.domain.root, local.domain.holo])
  account_id = data.cloudflare_zone.domain.account.id
  zone_id    = data.cloudflare_zone.domain.id
  hostname   = each.value
  service    = "rbn-docs"
}
```

The custom-domain resource creates the DNS record and the certificate; nothing else in `tofu/` or in `wrangler.jsonc` may declare a record for either hostname.
The D1 database id is an identifier, not a credential, and is committed in `wrangler.jsonc`.

Ordering is a real constraint: the custom domain references a Worker by name, so the first `wrangler deploy` must precede the first `tofu apply` of this file.
That is a one-time bootstrap step and is recorded in the tasks.

_Alternative:_ `routes = [{ pattern, custom_domain: true }]` in `wrangler.jsonc`, which would have wrangler create the records.
Rejected because DNS for the zone is OpenTofu's, and two owners for one record is how drift starts.

### D7. CI deploys with `cloudflare/wrangler-action`

`.github/workflows/docs.yml` is rewritten: trigger on push to `main` with `paths: [docs/**]`, `bun install --frozen-lockfile`, `bun run nuxi build`, then `cloudflare/wrangler-action` with `workingDirectory: docs` and `command: deploy`.
It needs `CLOUDFLARE_API_TOKEN` (Workers Scripts: Edit, D1: Edit, scoped to the account) and `CLOUDFLARE_ACCOUNT_ID` as repository secrets, set by hand.
The `pages` permissions and the Pages deploy steps go away.

### D8. `.well-known` endpoints

- `webfinger.ts` is unchanged in behaviour; it additionally returns 404 when `event.context.site` is holonet (the middleware already does this, the check in the route is belt-and-braces for when the route is reused outside this middleware).
- `atproto-did.ts` returns `runtimeConfig.public.atprotoDid` as `text/plain`.
  The default in `nuxt.config.ts` is the DID from `modules/users/john/john.nix`; `NUXT_PUBLIC_ATPROTO_DID` overrides it at deploy time.
  The issuer URL in `webfinger.ts` moves to runtime config the same way (`NUXT_PUBLIC_OIDC_ISSUER`), so a future issuer change is a Worker variable, not a redeploy of code.

### D9. The `network` section and the rule file

`content/4.network/1.index.md` and `.navigation.yml` create the section with an index page that states what belongs there (sites, VLANs, the holonet mesh, relays, DNS) and points at `mikrotik/NETWORK-REFERENCE.md` as the source to port.
No content is ported in this change.

`docs/AGENTS.md` (with `paths: ["docs/**"]`) is the one place the two-site model, the allowlist location, the no-prerender rule and why, the Cloudflare ownership split, and the preview recipe are written down, linked as `.agents/rules/docs.md`.
`docs/README.md` stays as it is.

## Risks / Trade-offs

- [Docus's `nitro:config` hook re-adds `/` to prerender routes after the app config is read] → the app registers its own `nitro:config` hook, which runs after layer hooks, and the build check in the tasks fails loudly if any HTML lands in `.output/public`.
- [An existing apex record for `jm0.io` in the zone blocks the custom-domain create] → the tasks list the zone's records for both hostnames before the first apply and remove any that are not OpenTofu-managed.
- [D1 first-request population adds latency to the first hit after each deploy and, if it fails, every page 500s] → `just docs::preview` exercises the same path locally; the deploy workflow ends with a `curl` of `/` on both hosts and the WebFinger URL so a broken population fails the run, not the next visitor.
- [Search sections query ignores the allowlist] → the search override filters results client-side, which is sufficient for a presentation boundary and is stated as such in the spec.
- [`useRequestURL()` behind Cloudflare's proxy reports the public hostname correctly, but `wrangler dev` reports `localhost`] → the "first label is `holonet`" rule plus `holonet.localhost` keeps local and production identical; the dev task verifies both hostnames in `wrangler dev`.
- [nuxt-site-config's `site.url` is a single value, so canonical and sitemap URLs on the network site would name `jm0.io`] → leave `site.url` unset so it is inferred from the request host; the preview task checks the canonical tag on both hosts and, if inference does not hold, sets it per request in a plugin.
- [`wrangler` and `bun` versions drift between CI and the devshell] → `wrangler` is pinned in `package.json` and resolved from `bun.lock` in both places; `bun` is pinned by the devshell and `setup-bun` is given the same version.
- [Portability promise erodes] → the rule file names the three files allowed to know about Cloudflare, and the spec's hosting requirement makes it testable.

## Migration Plan

1. Land the app changes and verify locally with `just docs::dev` and `just docs::preview`.
2. Set the two repository secrets.
3. First deploy: `just docs::deploy` by hand (or merge and let the workflow run) so the Worker `rbn-docs` exists.
4. `just tofu::plan`, review that the only creates are the D1 database and two custom domains, then `just tofu::apply`.
   Paste the D1 id into `wrangler.jsonc` and redeploy.
5. Verify both hostnames, the WebFinger JRD, and the DID endpoint from outside the LAN.
6. Delete the GitHub Pages site configuration in the repository settings.

**Rollback:** `tofu destroy -target` the two custom domains (DNS for both hostnames disappears, nothing else is affected); the Worker and D1 can be left in place or removed from the dashboard.
The previous workflow is in history if GitHub Pages must come back.

## Open Questions

- Whether `useSiteConfig().url` is inferred per request on Workers without `site.url` set.
  Deferrable: the fallback (a per-request plugin) changes neither the specs nor the task list beyond one verification step already present.
- Whether `nuxt-llms` and `@nuxtjs/sitemap` need explicit per-route disabling on holonet, or whether the 404 from the middleware is enough for their generated routes.
  Deferrable: the spec states the observable outcome (404), and the middleware already covers it; this only affects whether a module-level setting is also needed to keep build logs quiet.
