## Purpose

How the Hubitat hub and Home Assistant reach each other: the hub's web UI through the gateway behind authentik, its Maker API only from inside the cluster, and the hub's event posts to Home Assistant by a LAN name — never through the internet-facing gateway in either direction.

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

### Requirement: The hub posts events to Home Assistant by a LAN name

The Maker API's event URL on the hub SHALL be `http://ha-events.<dc-domain>:39501`, where `ha-events.<dc-domain>` resolves on the lab VLAN to a LoadBalancer address owned by Home Assistant's event-receiver Service.
The event URL SHALL NOT contain a node or pod IP, and the path SHALL NOT pass through the WAN-facing gateway.

#### Scenario: Name resolves to the event receiver

- **WHEN** `ha-events.<dc-domain>` is resolved from a device on the lab VLAN and port 39501 is connected
- **THEN** the address is the LoadBalancer address of the event Service and Home Assistant's event server answers

#### Scenario: Events arrive by name

- **WHEN** the integration's `server_url` is set to `http://ha-events.<dc-domain>:39501` and a paddle is pressed on a hub-connected switch
- **THEN** the hub's Maker API event URL reads that name and the switch's entity updates in Home Assistant within a second

#### Scenario: Home Assistant moving does not touch the hub

- **WHEN** the Home Assistant pod is rescheduled or restarted
- **THEN** the LoadBalancer address and the name still deliver events, and the hub's Maker API configuration is unchanged

### Requirement: The hub UI stays behind authentik on the gateway

Every other hub path on the public hostname SHALL continue to be served through the gateway with authentik in front, exactly as before this change.

#### Scenario: UI unaffected

- **WHEN** `https://hubitat.<dc-domain>/device/list` is opened in a browser with an authentik session
- **THEN** the hub's device list renders and device-page commands complete
