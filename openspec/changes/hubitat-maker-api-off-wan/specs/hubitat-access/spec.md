## Purpose

How the Hubitat hub is reachable: its web UI through the gateway behind authentik, and its Maker API only from inside the cluster, never from the internet.

## ADDED Requirements

### Requirement: The Maker API is reachable only from inside the cluster

The hub's Maker API (`/apps/api/...`) SHALL NOT be routed to the hub from the WAN-facing gateway; a request to it on the public hostname SHALL receive the same authentik response as any other hub path.
Inside the cluster the Maker API SHALL be reachable through the `hubitat` Service in namespace `home-automation`, and Home Assistant's Hubitat integration SHALL use that Service name as its host.

#### Scenario: Public path is closed

- **WHEN** `https://hubitat.<dc-domain>/apps/api/<app>/devices?access_token=<valid token>` is requested from outside the cluster without an authentik session
- **THEN** the response is authentik's login redirect, not device data

#### Scenario: Cluster path is open

- **WHEN** the same request is made to `http://hubitat.home-automation.svc.cluster.local/apps/api/<app>/devices?access_token=<valid token>` from the cluster
- **THEN** the hub returns the device list

#### Scenario: Home Assistant keeps working across the move

- **WHEN** the integration's host is changed to the Service name and a device command is issued from Home Assistant, and a device event occurs on the hub
- **THEN** the command reaches the device and the event reaches Home Assistant, with the same entity ids as before

### Requirement: The hub UI stays behind authentik on the gateway

Every other hub path on the public hostname SHALL continue to be served through the gateway with authentik in front, exactly as before this change.

#### Scenario: UI unaffected

- **WHEN** `https://hubitat.<dc-domain>/device/list` is opened in a browser with an authentik session
- **THEN** the hub's device list renders and device-page commands complete
