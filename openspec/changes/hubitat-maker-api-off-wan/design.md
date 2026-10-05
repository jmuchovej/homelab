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

## Goals / Non-Goals

**Goals:**

- No public route to the Maker API; Home Assistant unaffected in function and entity identity.
- Verified from both sides: the public path answers with authentik, the cluster path answers with devices.

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

### D4. Verification is end to end, from both network positions

Public: `curl` the Maker API URL with the real token from outside the cluster and expect authentik's redirect, not JSON.
Cluster: the same call from a pod (or from the node, since HA shares its network) returns the device list.
Function: one command from HA to a hub device and one physical event observed in HA.
Entity identity: an entity id noted before the move is unchanged after it.

## Risks / Trade-offs

- [The installed integration version cannot change the host in place] → Remove and re-add the integration; unique ids are hub-derived, so entities and their automations survive. Note an entity id before starting so this is checked, not assumed.
- [The token is pasted into a terminal for the curl checks] → Use `secretspec run` with the token held as a secret, or run the check from HA's own log; never commit or log the token. The app id is not sensitive.
- [tofu plan shows more than the one skip-path diff] → Stop and read it; unrelated drift is not this change's to apply.
- [Something else was using the public Maker API path] → The route comment and HA are the only known consumers; the public-path check after removal doubles as the detector, and the revert is one commit.

## Migration Plan

1. Record an HA entity id and the current host in the integration.
2. Change the integration host to the Service name; verify HA still polls and controls a device.
3. Commit the route edits; user pushes; Flux applies.
4. Verify the public path answers with authentik and the cluster path answers with devices; `just tofu-plan` shows the skip-path removal; apply it.
5. Rollback: revert the route commit (public path returns); point HA back at the public hostname if ever needed.
