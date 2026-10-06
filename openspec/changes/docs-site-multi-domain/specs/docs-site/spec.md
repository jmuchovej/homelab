## Purpose

Defines the public documentation site as a single application that answers two hostnames: which landing page and which documentation each host exposes, the root-domain-only `.well-known` endpoints the site provides for external tools, and the hosting and ownership contract that keeps the site server-rendered, public, and portable.

## ADDED Requirements

### Requirement: One application serves both hostnames

The documentation site SHALL be a single application that serves `jm0.io` (the root site) and `holonet.jm0.io` (the network site) and SHALL select the site from the request's hostname on every request, on both the server-rendered and the client-navigated path.
A hostname whose first label is `holonet` SHALL resolve to the network site; every other hostname SHALL resolve to the root site.
The site SHALL NOT be selected from a build-time flag, a path prefix, or a cookie.

#### Scenario: Same build, different hosts

- **WHEN** the same deployed build receives `GET /` with `Host: jm0.io` and `GET /` with `Host: holonet.jm0.io`
- **THEN** the two responses render different landing pages and neither response is a redirect

#### Scenario: Local preview resolves the network site by label

- **WHEN** the application is served locally and a request arrives with a hostname of `holonet.localhost`
- **THEN** the network site is rendered, with no configuration change from the production build

### Requirement: Each site has its own landing page

Each site SHALL have a landing page authored as a Markdown document in the content tree and rendered at `/` on that site's host.
Landing documents SHALL NOT appear in any site's navigation, sidebar, or search results.
A request for a landing document by its own content path on the host that does not own it SHALL redirect permanently to `/` on the owning host.

#### Scenario: Root landing at root apex

- **WHEN** `GET /` arrives with `Host: jm0.io`
- **THEN** the response is the root landing document rendered as a page, with status 200

#### Scenario: Network landing at network host

- **WHEN** `GET /` arrives with `Host: holonet.jm0.io`
- **THEN** the response is the network landing document rendered as a page, with status 200

#### Scenario: Landing document reached by path redirects to its host

- **WHEN** `GET /holonet` arrives with `Host: jm0.io`
- **THEN** the response is a 301 to `https://holonet.jm0.io/`

#### Scenario: Landing documents are hidden

- **WHEN** the navigation tree or search index for either site is produced
- **THEN** neither landing document is present in it

### Requirement: The root site exposes everything

The root site SHALL serve every document in the content tree at its content path, with the full navigation tree, sidebar, and search index.

#### Scenario: Every section is reachable on the root site

- **WHEN** `GET /reference`, `GET /guides`, `GET /homelab-cli`, and `GET /network` arrive with `Host: jm0.io`
- **THEN** each responds 200 with the matching section page, and each section appears in the header navigation

### Requirement: The network site exposes an explicit subset

The network site SHALL serve only its landing page, the `network` documentation section, and the static assets the application needs to render those pages.
Every other path SHALL respond 404, including other documentation sections, the `.well-known` endpoints, and the machine-readable site indexes (`sitemap.xml`, `llms.txt`, `llms-full.txt`).
The network site's header navigation, sidebar, and search index SHALL contain only the `network` section.
The subset SHALL be a single declared allowlist consulted by both the server and the client-side router, so that a direct request and an in-app navigation to the same path get the same answer.

#### Scenario: Network section served

- **WHEN** `GET /network` arrives with `Host: holonet.jm0.io`
- **THEN** the response is 200 and the rendered page's navigation contains only the `network` section

#### Scenario: Other sections refused

- **WHEN** `GET /reference/aspects` arrives with `Host: holonet.jm0.io`
- **THEN** the response is 404 and no document content is rendered

#### Scenario: Site indexes refused

- **WHEN** `GET /sitemap.xml` or `GET /llms.txt` arrives with `Host: holonet.jm0.io`
- **THEN** the response is 404

#### Scenario: Client-side navigation is bounded the same way

- **WHEN** a visitor on `holonet.jm0.io` navigates in-app to a path outside the allowlist
- **THEN** the application shows its 404 page without rendering the document

#### Scenario: Search is scoped

- **WHEN** a visitor on `holonet.jm0.io` searches for a term that appears only in the `reference` section
- **THEN** no result is returned for it

#### Scenario: Restriction is not a disclosure boundary

- **WHEN** the same document is requested on `jm0.io`
- **THEN** it is served, because both sites are public and the allowlist governs presentation, not access

### Requirement: WebFinger discovery on the root domain

The root site SHALL serve `GET /.well-known/webfinger` over public HTTPS as an RFC 7033 JSON Resource Descriptor, so that Tailscale's control plane can discover the OpenID issuer for `@jm0.io` accounts.
The `resource` query parameter SHALL be required; a request without it SHALL respond 400.
A `resource` whose account domain is not `jm0.io` SHALL respond 404.
A successful response SHALL carry `application/jrd+json`, SHALL echo the requested `resource` as `subject`, and SHALL include a link with `rel` `http://openid.net/specs/connect/1.0/issuer` whose `href` is the issuer URL of the Tailscale application on `id.jm0.io`.
When one or more `rel` parameters are supplied, only matching links SHALL be returned.
The endpoint SHALL NOT be gated on the caller's network, because the probe originates from Tailscale's public infrastructure rather than from the tailnet.
The endpoint SHALL NOT be served on the network site.

#### Scenario: Tailscale probe

- **WHEN** `GET /.well-known/webfinger?resource=acct:someone@jm0.io` arrives at `https://jm0.io` from the public internet
- **THEN** the response is 200 `application/jrd+json` with `subject` equal to `acct:someone@jm0.io` and a `links` entry whose `rel` is the OpenID issuer relation and whose `href` is `https://id.jm0.io/application/o/tailscale/`

#### Scenario: Foreign domain

- **WHEN** `GET /.well-known/webfinger?resource=acct:someone@example.com` arrives at `https://jm0.io`
- **THEN** the response is 404

#### Scenario: Missing resource

- **WHEN** `GET /.well-known/webfinger` arrives with no `resource` parameter
- **THEN** the response is 400

#### Scenario: Not on the network site

- **WHEN** `GET /.well-known/webfinger?resource=acct:someone@jm0.io` arrives with `Host: holonet.jm0.io`
- **THEN** the response is 404

### Requirement: AT Protocol handle verification on the root domain

The root site SHALL serve `GET /.well-known/atproto-did` as `text/plain` whose body is exactly the DID that `jm0.io` is a handle for, with no trailing content other than an optional newline.
The DID value SHALL be configurable at deploy time without a code change.
The endpoint SHALL NOT be served on the network site.

#### Scenario: Handle verification

- **WHEN** `GET /.well-known/atproto-did` arrives at `https://jm0.io`
- **THEN** the response is 200 `text/plain` and its body is a `did:plc:` identifier matching the configured value

#### Scenario: Not on the network site

- **WHEN** `GET /.well-known/atproto-did` arrives with `Host: holonet.jm0.io`
- **THEN** the response is 404

### Requirement: Server-rendered, public hosting

The site SHALL be served by a server-side-rendered runtime reachable from the public internet over HTTPS on both hostnames.
No page SHALL be prerendered to a static file at build time, so that every page request passes through host resolution.
Both sites SHALL be public; no authentication SHALL be placed in front of either.
The application SHALL depend on the hosting platform only through its server runtime adapter and its content database adapter, so that moving it to a container behind the cluster ingress later requires no change to routes, pages, or content.

#### Scenario: Both hostnames resolve to the same deployment

- **WHEN** DNS for `jm0.io` and `holonet.jm0.io` is resolved and each is fetched over HTTPS
- **THEN** both are served by the current deployment of the site, with valid certificates, and the site a visitor sees is determined by the hostname alone

#### Scenario: Nothing is prerendered

- **WHEN** the production build output is inspected
- **THEN** it contains the application's static assets and no prerendered HTML document for any content path

### Requirement: Cloud resources are declared in OpenTofu, the deploy is not

The hosting platform's resources the site depends on, specifically the content database and the binding of each hostname to the deployed application, SHALL be declared in the repository's OpenTofu root alongside the DNS zone.
The deploy of the application itself SHALL be performed by continuous integration on pushes to the default branch that touch `docs/`, using credentials held as repository secrets rather than in OpenTofu state.
Neither hostname's DNS record SHALL be created by hand or by the deploy tool; the hostname binding resource owns it.

#### Scenario: Hostnames are bound by OpenTofu

- **WHEN** `just tofu::plan` is run after this change is applied
- **THEN** it reports no changes, and the state contains the content database and a hostname binding for each of `jm0.io` and `holonet.jm0.io`

#### Scenario: Deploy runs from CI

- **WHEN** a commit touching `docs/` lands on the default branch
- **THEN** the documentation workflow builds the site and deploys it, and a commit touching nothing under `docs/` does not trigger it

#### Scenario: Deploy credentials stay out of OpenTofu

- **WHEN** the OpenTofu state is inspected
- **THEN** it contains no API token used by the deploy workflow

### Requirement: Local development and preview

The `docs/` tree SHALL provide `just` recipes to run the site locally against a local content database and to preview the production build in a local emulation of the hosting runtime, so that both the host split and the `.well-known` endpoints can be exercised before a deploy.
The root justfile SHALL load these recipes as a `docs` module.

#### Scenario: Dev server

- **WHEN** `just docs::dev` is run
- **THEN** the site is served locally, `http://localhost:<port>/` renders the root landing, and `http://holonet.localhost:<port>/` renders the network landing

#### Scenario: Production preview

- **WHEN** `just docs::preview` is run after a build
- **THEN** the production bundle is served by the local runtime emulation, and `GET /.well-known/webfinger?resource=acct:someone@jm0.io` returns the JRD described above
