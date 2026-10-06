## 1. Baseline (hub and Home Assistant, by hand)

- [ ] 1.1 In Home Assistant, note the Hubitat integration's current host and `server_url`, one Hubitat-backed entity id (for example a dimmer's light entity), and the Maker API's current event URL from the app's page on the hub (`http://10.32.11.1:39501`) in a scratch note; verify the note holds all four before continuing
- [ ] 1.2 Confirm the Maker API answers from inside the cluster before anything changes: from the node (HA shares its network) `curl -s 'http://hubitat.home-automation.svc.cluster.local/apps/api/28/devices?access_token=…'` with the token supplied through `secretspec run` or pasted only into the shell; verify it returns the device list JSON

## 2. A name for Home Assistant's event receiver (repo)

- [ ] 2.1 `kubernetes/apps/home-automation/home-assistant/app/helm-release.yaml`: add `service.events` with `type: LoadBalancer`, `lbipam.cilium.io/ips: "${LB_PREFIX}.45"`, `externalTrafficPolicy: Local`, and one port `events` 39501 on the same controller as `service.app`; verify `kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/apps/home-automation/home-assistant/app` builds and the rendered HelmRelease shows the block
- [ ] 2.2 `tofu/cloudflare/da.tofu`: add `routeros_ip_dns_record "da-ha-events"` (provider `routeros.da-relay01`, type A, name `ha-events.${local.domain.da}`, address the lab prefix plus `.45`, comment naming the Home Assistant event Service) beside the apex and wildcard records; verify `just tofu-plan` shows exactly one new record
- [ ] 2.3 Commit as `feat(kubernetes): name Home Assistant's Hubitat event receiver on the LAN` with an explicit fileset (the two files); verify `jj diff -r @- --stat` lists only them.
      Push is the user's
- [ ] 2.4 (after push) Wait for Flux to apply the Home Assistant release; verify `kubectl get svc -n home-automation` shows the `events` Service with the `.45` address and `kubectl get endpointslice -n home-automation -l kubernetes.io/service-name=<svc>` lists `10.32.11.1:39501`; `just tofu-apply` the record; verify `dig +short ha-events.<dc-domain>` from the LAN returns the address and `nc -z ha-events.<dc-domain> 39501` connects

## 3. Repoint Home Assistant (by hand)

- [ ] 3.1 In the Hubitat integration's configuration, set the host to `http://hubitat.home-automation.svc.cluster.local` (same app id and token) and `server_url` to `http://ha-events.<dc-domain>:39501`; if the installed version offers no host field, remove the integration and add it again with both values; verify the integration loads without error
- [ ] 3.2 Open the Maker API app on the hub; verify its event URL now reads `http://ha-events.<dc-domain>:39501` (set it by hand to that value if the integration did not rewrite it)
- [ ] 3.3 Verify function while the public path still exists: toggle one hub device from HA and see it respond; press a paddle on one switch and see the entity update in HA within a second; verify the entity id from 1.1 is unchanged

## 4. Close the public path (repo)

- [ ] 4.1 `kubernetes/apps/home-automation/hubitat/app/http-route.yaml`: delete the `/apps/api` rule and its comment from `hubitat-outpost`, and the `authentik.rbn/skip-paths` annotation from `hubitat`; keep the `/outpost.goauthentik.io` rule; verify `check-k8s-schemas` passes with the substitution variables supplied and the app kustomization builds
- [ ] 4.2 `kubernetes/apps/network/envoy-gateway/config/client-traffic-policy.yaml`: reword the comment so the escaped-slash setting is described as kept for Traefik-era compatibility, with the Maker API callbacks as its original reason, not a current one; verify no YAML outside the comment changes
- [ ] 4.3 Commit as `fix(kubernetes): take the hubitat Maker API off the WAN gateway` with an explicit fileset (the two files); verify `jj diff -r @- --stat` lists only them.
      Push is the user's

## 5. Verify after Flux applies

- [ ] 5.1 Wait for `kubectl get kustomization hubitat -n home-automation` to show the pushed revision; verify the live `hubitat-outpost` HTTPRoute has one rule
- [ ] 5.2 From outside the cluster, `curl -sS -o /dev/null -D - 'https://hubitat.<dc-domain>/apps/api/28/devices?access_token=…'`; verify the response is authentik's `302` to `id.jm0.io`, not `200` JSON
- [ ] 5.3 Repeat 1.2 from inside the cluster; verify the device list still comes back
- [ ] 5.4 Repeat 3.3 (command from HA, paddle event into HA); verify both still work with the public path gone
- [ ] 5.5 `just tofu-plan`; verify the only diff is the hubitat authentik provider losing `skip_paths`; `just tofu-apply`; verify the plan afterwards is clean

## 6. Record

- [ ] 6.1 Add the convention to `kubernetes/AGENTS.md` under Networking: an in-cluster consumer of a LAN device reaches it through the device's selectorless Service, a LAN device that must call into the cluster gets a LoadBalancer Service plus a router A record (the octet written in both places, as a pair), and the WAN gateway carries no auth bypasses for machine clients; verify the sentences land in the existing Networking section rather than a new rule file
- [ ] 6.2 Commit as `docs(kubernetes): LAN devices and the cluster address each other by name` and `chore(openspec): record hubitat-maker-api-off-wan results`; verify scoped diffs
