## Why

The hub's Maker API (app 28, used by Home Assistant's Hubitat integration) is reachable from the internet: the `hubitat-outpost` HTTPRoute forwards `/apps/api` on the WAN-facing gateway with authentik deliberately bypassed, so the only lock on every device command is the API's `access_token`.
The one legitimate caller is Home Assistant, which runs in the same cluster and can reach the hub through the existing `hubitat` Service without any public path.
Removing the bypass closes a public surface for free.
The reverse direction has the mirror-image problem: the hub posts device events to `http://10.32.11.1:39501`, a raw node address that changes whenever Home Assistant moves.
Both directions should address the other side by a stable name, and neither should cross the WAN gateway.

## What Changes

- Home Assistant's Hubitat integration is pointed at `http://hubitat.home-automation.svc.cluster.local` instead of `https://hubitat.da.jm0.io`.
  Same app id, same token; only the host changes.
- Home Assistant's event receiver (the integration's server on port 39501) gets a LoadBalancer Service with a fixed address from the Cilium pool and a router DNS record `ha-events.<dc-domain>`, and the integration's `server_url` is set to `http://ha-events.<dc-domain>:39501`, which it writes into the Maker API's event URL.
  The hub then posts events to a name on the lab VLAN; nothing public, no gateway, no authentik.
- The `/apps/api` rule is removed from the `hubitat-outpost` HTTPRoute and the `authentik.rbn/skip-paths: /apps/api/*` annotation from the `hubitat` HTTPRoute, so the authentik provider that tofu derives from that annotation no longer carries a skip path either.
- The comment on the gateway's `ClientTrafficPolicy` (escaped-slash handling introduced for Maker API callbacks through the gateway) is updated to say the rationale is historical; the setting itself stays, since changing gateway-wide path normalisation is out of scope.
- **Not changed**: the Maker API app, its token, the hub, HA's event server, the `hubitat` Service and EndpointSlice (already present as the route's backend), the authentik-protected UI path.

## Capabilities

### New Capabilities

- `hubitat-access`: how the Hubitat hub and Home Assistant reach each other — the hub's UI through the gateway behind authentik, the Maker API only from inside the cluster, and the hub's event posts to Home Assistant by a LAN name that never touches the WAN gateway.

### Modified Capabilities

- None.

## Impact

- **Home Assistant**: one host change in the Hubitat integration, done in HA's UI (the integration's configuration lives in HA's storage, not in this repo).
  If the installed integration version cannot change the host in place, the entry is removed and re-added; its entities keep their ids because the integration derives unique ids from the hub and device ids, which do not change.
  Automations keep working either way.
- **Network**: after the change, `https://hubitat.da.jm0.io/apps/api/...` is answered by authentik like every other hub path; from inside the cluster the Maker API answers at the Service name.
  HA runs with `hostNetwork: true` and `ClusterFirstWithHostNet` DNS, so it resolves the Service name and reaches the ClusterIP from the node; no network-policy grant is involved.
- **authentik / tofu**: the hubitat provider loses its `/apps/api/*` skip path, and the da router gains one A record (`ha-events.<dc-domain>` → the new LoadBalancer address); `just tofu-plan` shows exactly those two diffs and `tofu apply` lands them.
- **Home Assistant, event side**: a second Service on the app-template release (`type: LoadBalancer`, one pool address, port 39501) pointing at the same pod; HA runs `hostNetwork`, so the endpoint is the node and the integration's listener needs nothing changed.
  Setting `server_url` in the integration makes it rewrite the Maker API's event URL on the hub; the old raw-address URL is replaced, not duplicated.
  If the integration ever moves to another node, the LoadBalancer address and the name follow it; the hub's configuration does not change again.
- **Repo**: two HTTPRoute edits, one comment, one Service block in the Home Assistant release, one DNS record in tofu.
- **Found while surveying, not touched here**: `kubernetes/apps/home/mikrotik/app/http-route.yaml` (uncommitted work in progress) contains a second HTTPRoute named `hubitat` with hostname `hubitat.${DC_DOMAIN}` and a `/apps/api` rule, apparently copied from the hubitat app.
  If it ships as-is it would duplicate the hub's hostname and re-open the bypass; it needs its name, hostname, and rules replaced before that app is committed.
