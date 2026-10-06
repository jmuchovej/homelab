## Context

See proposal.md for motivation. What was verified before planning:

- **Routes.** `kubernetes/apps/home-automation/hubitat/app/http-route.yaml` holds two HTTPRoutes: `hubitat-outpost` (not targeted by the SecurityPolicy) with a `/outpost.goauthentik.io` rule for the auth flow and a `/apps/api` rule to the hub, and `hubitat` (ext-auth via `security-policy.yaml`) carrying the `authentik.rbn/*` annotations including `skip-paths: /apps/api/*`.
  The `/apps/api` rule exists because authentik's own `skip_paths` cannot exempt the path under Envoy ext-auth (the outpost 301s encoded slashes before its skip regex runs), as the route comment records.
- **Backend.** The `hubitat` Service (selectorless, `${LAB_PREFIX}.4.2:80` via `endpoint-slice.yaml`) is already what both routes send to.
  Its cluster name is `hubitat.home-automation.svc.cluster.local`.
- **Home Assistant** is deployed in `home-automation` with `hostNetwork: true` and `dnsPolicy: ClusterFirstWithHostNet`: it can resolve Service names and reach ClusterIPs from the node, and it is not a pod-network endpoint for Cilium policy purposes.
  The Hubitat integration's host and token live in HA's `.storage`, not in this repo; nothing in `app/config` references the hub.
- **Maker API** on the hub is app 28, labelled "Home Assistant".
  Calls run HA → hub (polling and commands, with `access_token`) and hub → HA (events POSTed to the URL the integration registered on install); only the first direction uses a route.
- **authentik discovery.** `tofu/kubernetes/main.tofu` reads `authentik.rbn/skip-paths` off HTTPRoutes into the provider's `skip_paths`; removing the annotation makes that `null`.
- **ClientTrafficPolicy** `envoy-external` sets `escapedSlashesAction: KeepUnchanged` and `disableMergeSlashes: true` gateway-wide; its comment attributes this to Maker API `postURL` paths crossing the gateway.
- **Hub → HA today.** The Maker API's event URL is `http://10.32.11.1:39501`.
  In `jason0x43/hacs-hubitat` the listener port defaults to 0, an ephemeral port chosen at each start, so 39501 is a value the integration was given, either as `server_port` or as the port inside `server_url`; with no `server_url` the event URL defaults to the listener's own address and port.
  The listener's bind address is the source address of a UDP connect to the hub's host, and the integration sends the event URL to the Maker API (`postURL`) every time the listener starts, i.e. on every HA start and every options change, so the hub's value is owned by HA and a hand edit on the hub is overwritten at the next reload.
  Host, `server_url`, and `server_port` are all editable in the options flow, and any change reloads the entry.
  There is no YAML path: `async_setup` is a stub and the config flow has no import step, so these values live only in HA's `.storage`.
  The hub cannot resolve cluster DNS or route to ClusterIPs, so the Service-name trick does not work in this direction.
- **Bind address with a Service-name host.** Cilium's socket LB is on with `hostNamespaceOnly: true`, and HA is `hostNetwork`, so the UDP connect to the Service name is translated at the socket to the hub's lab address and the node's lab-VLAN address is picked, as today.
  This is reasoned from the Cilium config, not observed; the LAN-side port check after the repoint is what confirms it.
- **Name-giving options on the LAN.** The router's `*.<dc-domain>` CNAME points at the external VIP, so an internal-only name needs its own `routeros_ip_dns_record` (tofu, `routeros.da-relay01` provider; the apex and wildcard records in `tofu/cloudflare/da.tofu` are the pattern).
  `envoy-internal` listens on 80 and 443, but an `https-redirect` HTTPRoute is attached to its `http` section, so plain-http posts to the internal gateway would be answered with a 301 the hub's Maker API does not follow; only an https route would work there.
  Cilium LB-IPAM addresses in use: `.1`/`.2` gateways, `.32` plex, `.40` minecraft, `.5x` databases, `.61` valkey, the syncthing octet; app-template declares a LoadBalancer Service as `service.<name>.type: LoadBalancer` with `lbipam.cilium.io/ips` and `externalTrafficPolicy: Local` (plex).

## Goals / Non-Goals

**Goals:**

- No public route to the Maker API; Home Assistant unaffected in function and entity identity.
- Both directions address the other side by a stable name: HA uses the hub's cluster Service, the hub uses a LAN name for HA's event receiver; no raw IP in either configuration.
- Verified from both sides: the public path answers with authentik, the cluster path answers with devices, and a paddle press reaches HA through the name.

**Non-Goals:**

- Changing the Maker API token, the hub's security settings, or HA's event server.
- Re-tuning the gateway's path normalisation (the ClientTrafficPolicy stays; only its comment changes).
- Fixing the stray `hubitat` HTTPRoute inside the uncommitted mikrotik app; it is flagged in the proposal and belongs to that work.

## Decisions

### D1. Home Assistant uses the cluster Service name, not the LAN IP and not an internal gateway route

`http://hubitat.home-automation.svc.cluster.local` is already the route's backend, survives the hub changing address (one EndpointSlice edit), and introduces no new resource.
Rejected: the raw LAN IP (works, but the user prefers names and it would need updating by hand); a second HTTPRoute on `envoy-internal` for `/apps/api` (keeps a hostname-based path open on the LAN for one in-cluster caller, more moving parts than a DNS name); Envoy Gateway `SecurityPolicy.authorization` by client CIDR on the existing bypass (keeps a public path open in order to filter it).

### D2. Remove the bypass rule and the skip-paths annotation together

The rule and the annotation describe the same exemption at two layers; leaving either is a dangling promise.
The authentik side follows automatically through tofu's discovery, so no tofu file changes, only a plan showing one provider diff.

### D3. Order of operations: HA first, then the route

HA is repointed and verified while the public path still works, so a mistake in the HA step is visible before anything is removed.
Only then is the route commit pushed.
Rollback at any point before the push is nothing; after it, reverting the commit restores the bypass.

### D4. Hub → HA events go to a LoadBalancer Service with a router A record, on the existing port

A second app-template Service on the Home Assistant release, `events`: `type: LoadBalancer`, `lbipam.cilium.io/ips: "${LB_PREFIX}.45"`, `externalTrafficPolicy: Local`, port 39501 to the same pod (which, being `hostNetwork`, is the node).
A tofu `routeros_ip_dns_record` A record `ha-events.<dc-domain>` → that address, beside the da apex and wildcard records.
The integration's `server_url` becomes `http://ha-events.<dc-domain>:39501` and `server_port` stays 39501; the URL's port alone would pin the listener, but the explicit port keeps the two from drifting if either is edited later.
The reload that follows sends the new event URL to the Maker API, so the hub's side is configured by HA, never by hand.
The scheme stays http and the port stays the one already in use, so only the address changes, to a name that follows the pod.
Rejected: an HTTPRoute on `envoy-internal` (the http listener 301s to https, which would force an https event URL and make event delivery depend on the gateway and its certificate for a LAN-internal hop); keeping the raw node IP (works, but it is the thing the user asked to stop doing, and it breaks the day HA moves); a LAN DNS name for the node itself (`<host>.<dc-domain>` already points at Envoy by convention, and it would still tie the hub to a node rather than to HA).
`.45` is a free address in the pool; the existing octets are 1, 2, 32, 40, 5x, 61 and the syncthing octet, with no block convention to follow.

### D5. Verification is end to end, from both network positions

Public: `curl` the Maker API URL with the real token from outside the cluster and expect authentik's redirect, not JSON.
Cluster: the same call from a pod (or from the node, since HA shares its network) returns the device list.
Events: the Maker API app page shows the event URL as the name; a paddle press on a hub switch updates its entity in HA; `dig ha-events.<dc-domain>` from the LAN returns the LoadBalancer address.
Function: one command from HA to a hub device and one physical event observed in HA.
Entity identity: an entity id noted before the move is unchanged after it.

## Risks / Trade-offs

- [The host cannot be changed in place] → The current options flow edits host, `server_url`, and `server_port` directly and reloads the entry; remove-and-re-add is only for an old version, and unique ids are hub-derived so entities survive either way. Note an entity id before starting so this is checked, not assumed.
- [The token is pasted into a terminal for the curl checks] → Use `secretspec run` with the token held as a secret, or run the check from HA's own log; never commit or log the token. The app id is not sensitive.
- [tofu plan shows more than the one skip-path diff] → Stop and read it; unrelated drift is not this change's to apply.
- [Something else was using the public Maker API path] → The route comment and HA are the only known consumers; the public-path check after removal doubles as the detector, and the revert is one commit.
- [The LoadBalancer Service does not reach a `hostNetwork` pod] → The pod's address is the node's, so the endpoint is `10.32.11.1:39501`, the same place the hub posts today; `kubectl get endpointslice` for the Service shows it before the hub is repointed, and the old URL keeps working until the integration rewrites it.
- [`externalTrafficPolicy: Local` plus a single node] → Fine today; if HA ever lands on another node the address moves with the pod through BGP, which is the point. On a multi-node cluster the policy keeps the hub's source address visible to HA, as it does for plex.
- [The hub's event URL still shows the IP after the reload] → The integration sends `postURL` on every listener start, so a stale value means the option did not save or the reload failed; fix it in the options flow, never on the hub, where a hand edit is overwritten at the next HA start.
- [The listener binds to an address the LoadBalancer cannot reach] → The bind address is chosen by a UDP connect to the hub host; with socket LB in the host namespace the Service name resolves to the hub's lab address and the node's lab-VLAN address is picked, as today. `nc -z ha-events.<dc-domain> 39501` from the LAN after the repoint is the check; if it fails, HA's debug log line `Listening on <address>:<port>` names the address actually bound.
- [Router DNS record and LB address drift apart] → Both live in this repo (tofu record, release annotation) with the octet written in both places; the AGENTS note added in 5.x says they are a pair.

## Migration Plan

1. Record an HA entity id, the integration's current host, and the Maker API's current event URL.
2. Repo: add the `events` Service to the Home Assistant release and the `ha-events` A record in tofu; commit; user pushes; Flux applies the Service; `just tofu-apply` lands the record. Verify the name resolves to the address and the port answers, while the hub still posts to the old URL.
3. Change the integration's host to the Service name and its `server_url` to the new name; reload the integration; verify it polls, controls a device, and that the Maker API's event URL now reads the name; press a paddle and see the entity update.
4. Commit the route edits; user pushes; Flux applies.
5. Verify the public path answers with authentik and the cluster path answers with devices; `just tofu-plan` shows only the skip-path removal (the record already applied); apply it.
6. Rollback: revert the route commit (public path returns); set the integration's host and `server_url` back to the previous values if ever needed. The Service and record are inert if unused.
