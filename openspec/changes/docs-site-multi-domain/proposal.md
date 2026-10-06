# One Nuxt app, two public sites: `jm0.io` and `holonet.jm0.io`

## Why

The `docs/` tree is a semi-scaffolded Docus site that already carries real obligations the current scaffold cannot meet.
Its `server/routes/.well-known/webfinger.ts` is the Tailscale custom-OIDC discovery endpoint that lets people sign in as `@jm0.io` instead of `@id.jm0.io`, and it needs the `?resource=` query and a 404 path, which only run under server-side rendering.
Its `.github/workflows/docs.yml`, however, runs `nuxi generate` and ships static HTML to GitHub Pages, where that route can never execute.
Nothing in `tofu/` owns the `jm0.io` apex or `holonet.jm0.io`, so neither hostname resolves to anything today.

The second obligation is the split you described: `jm0.io` is the homelab's front door, and `holonet.jm0.io` is the network's front door, with its own landing page and only a subset of the documentation behind it.
Maintaining two Nuxt apps to get two landing pages is the thing to avoid; the subset relationship means one app can serve both if it knows which host it is answering.

Hosting is the forcing function for doing this now rather than later.
You want the site in-cluster eventually, behind a Cloudflare Tunnel like `id.jm0.io`, but only once a Coolify-style deploy path exists so a website does not need the full Kubernetes pipeline.
Until then the site needs somewhere to run that is public, server-side rendered, and owned by the same tooling that already owns the zone.

## What Changes

- **One app answers two hostnames by Host header.**
  `jm0.io` renders The Rebellion landing page and exposes every documentation section.
  `holonet.jm0.io` renders a network landing page and exposes only the network section.
  Every other path on `holonet.jm0.io` is a 404, including the `.well-known` endpoints and the machine-readable indexes (sitemap, llms.txt).
  Navigation, sidebar, and search on the network site are trimmed to the same subset.
- **Each landing page is a Markdown document, hidden from navigation, rendered at `/` by its own host.**
  Hitting a landing document by its own path on the other host redirects to the host that owns it.
- **A new `network` documentation section** is created as the content that `holonet.jm0.io` exposes.
  It is seeded with an index page and section scaffold; porting `mikrotik/NETWORK-REFERENCE.md` and friends into it is content work that follows this change.
- **`.well-known` endpoints are root-domain only.**
  The existing WebFinger route stays as written.
  The empty `atproto-did.ts` becomes a working route returning the Bluesky DID already recorded in `modules/users/john/john.nix`.
- **BREAKING (deployment): the site moves from GitHub Pages to a Cloudflare Worker.**
  The Nuxt build targets the `cloudflare_module` Nitro preset, Nuxt Content uses a Cloudflare D1 database at runtime, and page prerendering is turned off so every page request passes through the host-aware server.
  The GitHub Pages workflow is replaced by a wrangler deploy on pushes that touch `docs/`.
- **Cloudflare infrastructure the site depends on is declared in `tofu/`:** the D1 database and the two Workers custom domains (`jm0.io`, `holonet.jm0.io`).
  wrangler owns only the Worker script.
  No DNS record for either hostname is written by hand or by wrangler.
- **`docs/` becomes a first-class root tree**: a `docs` module in the root justfile, and a `docs/AGENTS.md` rule linked into `.agents/rules/` describing the two-site model, the allowlist, and the hosting contract.
- **Portability is a constraint, not a feature.**
  Nothing in the app may depend on Cloudflare beyond the Nitro preset and the Content database adapter, so the later move in-cluster is a preset switch and a container, not a rewrite.

## Capabilities

### New Capabilities

- `docs-site`: the public documentation site as one application serving two hostnames: which host renders which landing page, which paths each host exposes, the root-domain-only `.well-known` endpoints and their contracts (Tailscale WebFinger, AT Protocol DID), the server-rendered hosting contract, and the ownership split between the Worker deploy and the Cloudflare resources declared in OpenTofu.

### Modified Capabilities

- `repo-layout`: the "Tool trees live at the repository root" requirement enumerates the tool-specific root trees and the modules the root justfile loads.
  This change adds `docs/` to that enumeration and a `docs` module to the justfile scenario.

## Impact

**Affected code**

- `docs/nuxt.config.ts`: Nitro preset, Content database, prerender off, runtime config for the DID and issuer.
- `docs/wrangler.jsonc` (new): Worker name, entry, assets, `nodejs_compat`, the D1 binding.
- `docs/shared/`, `docs/server/middleware/`, `docs/app/middleware/`, `docs/app/pages/index.vue` (new): host resolution, the per-host allowlist, and the per-host landing page.
- `docs/app/components/`: the existing navigation overrides gain site filtering; a search override is added for the same reason.
- `docs/content/`: `index.md` becomes a hidden landing document, a second landing document is added for the network site, and a `4.network/` section is created.
- `docs/server/routes/.well-known/atproto-did.ts`: implemented.
- `docs/justfile`, root `justfile`: `dev`, `preview`, and `deploy` recipes; `mod docs`.
- `.github/workflows/docs.yml`: rewritten for wrangler.
- `tofu/cf.docs.tofu` (new): D1 database and two Workers custom domains.
- `docs/AGENTS.md` and `.agents/rules/docs.md` (new).

**Dependencies**

- New runtime dependency on Cloudflare Workers and D1.
  `wrangler` is added as a dev dependency of `docs/`.
- Repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` for the deploy workflow.
  These are set in GitHub by hand; the OpenTofu root has no GitHub provider and should not gain one for this.

**Operational coupling**

- Tailscale login for `@jm0.io` accounts depends on `jm0.io/.well-known/webfinger`, which this change makes depend on the Worker being deployed.
  The issuer it points at is `id.jm0.io`, which is in-cluster, so the cluster dependency already exists and this change does not add a new one.
- Workers custom domains write their own DNS records in the zone.
  Any pre-existing apex record for `jm0.io` must be found and removed before the custom domain is applied, or the apply fails.
- The holonet restriction is a routing and presentation boundary, not a disclosure boundary.
  Both sites are public, every document is reachable on `jm0.io`, and the content query API serves the same database on both hosts.
  If either site is ever made private, Cloudflare Access in front of the Worker, pointing at `id.jm0.io`, is the mechanism, not this allowlist.

**Non-goals**

- In-cluster hosting, a container image, or a Coolify deploy.
  The app is kept portable so that change is small when it comes.
- Porting network documentation content.
  This change creates the section; filling it is ongoing content work.
- Private or authenticated sites.
- `www.jm0.io`, `da.jm0.io`, or any other hostname.
- Replacing the stock Docus `docs/README.md`.
