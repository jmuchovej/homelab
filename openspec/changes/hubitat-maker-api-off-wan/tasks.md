## 1. Baseline (hub and Home Assistant, by hand)

- [ ] 1.1 In Home Assistant, note the Hubitat integration's current host, and one Hubitat-backed entity id (for example a dimmer's light entity) in a scratch note; verify the note holds both before continuing
- [ ] 1.2 Confirm the Maker API answers from inside the cluster before anything changes: from a pod in `home-automation` or from the node, `curl -s 'http://hubitat.home-automation.svc.cluster.local/apps/api/28/devices?access_token=…'` with the token supplied through `secretspec run` or pasted only into the shell; verify it returns the device list JSON

## 2. Repoint Home Assistant

- [ ] 2.1 In the Hubitat integration's configuration, change the host to `http://hubitat.home-automation.svc.cluster.local` (same app id and token); if the installed version offers no host field, remove the integration and add it again with the Service host; verify the integration loads without error
- [ ] 2.2 Verify function from HA while the public path still exists: toggle one hub device from HA and see it respond; press a paddle on one switch and see the entity update in HA; verify the entity id from 1.1 is unchanged

## 3. Close the public path (repo)

- [ ] 3.1 `kubernetes/apps/home-automation/hubitat/app/http-route.yaml`: delete the `/apps/api` rule and its comment from `hubitat-outpost`, and the `authentik.rbn/skip-paths` annotation from `hubitat`; keep the `/outpost.goauthentik.io` rule; verify `check-k8s-schemas` passes with the substitution variables supplied and `kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/apps/home-automation/hubitat/app` builds
- [ ] 3.2 `kubernetes/apps/network/envoy-gateway/config/client-traffic-policy.yaml`: reword the comment so the escaped-slash setting is described as kept for Traefik-era compatibility, with the Maker API callbacks as its original reason, not a current one; verify no YAML outside the comment changes
- [ ] 3.3 Commit as `fix(kubernetes): take the hubitat Maker API off the WAN gateway` with an explicit fileset (the two files); verify `jj diff -r @- --stat` lists only them.
      Push is the user's

## 4. Verify after Flux applies

- [ ] 4.1 Wait for `kubectl get kustomization hubitat -n home-automation` to show the pushed revision; verify the live `hubitat-outpost` HTTPRoute has one rule
- [ ] 4.2 From outside the cluster, `curl -sS -o /dev/null -D - 'https://hubitat.<dc-domain>/apps/api/28/devices?access_token=…'`; verify the response is authentik's `302` to `id.jm0.io`, not `200` JSON
- [ ] 4.3 Repeat 1.2 from inside the cluster; verify the device list still comes back
- [ ] 4.4 Repeat 2.2 (command from HA, physical event into HA); verify both still work with the public path gone
- [ ] 4.5 `just tofu-plan`; verify the only diff is the hubitat authentik provider losing `skip_paths`; `just tofu-apply`; verify the plan afterwards is clean

## 5. Record

- [ ] 5.1 Add the Service-name convention to `kubernetes/AGENTS.md` under Networking: in-cluster consumers of a LAN device reach it through its selectorless Service, never through the public hostname, and the gateway carries no auth bypasses for machine clients that live in the cluster; verify the sentence lands in the existing Networking section rather than a new rule file
- [ ] 5.2 Commit as `docs(kubernetes): in-cluster callers use the Service, not the gateway` and `chore(openspec): record hubitat-maker-api-off-wan results`; verify scoped diffs
