## Context

See proposal.md for motivation. Facts that shape the approach, read from the libraries, the vendored Inovelli driver (`hubitat/drivers/inovelli-dimmer-blue-series-VZM31-SN.groovy`, the reference, not a dependency), and the hub:

- **How Inovelli's driver talks to `0xFC31`.** Parameters are attributes on the private cluster whose attribute id is the parameter number; reads and writes carry `mfgCode 0x122F`; sizes map to ZCL types (1 → boolean, 8 → uint8, 16 → uint16, 32 → uint32; internal temperature 32 is a signed int8). Mode changes (52, 258) are given a longer delay because the device reconfigures itself. Received reports are written straight into `settings` (`parameter<N>`, unpadded) and, for read-only parameters, emitted as attributes (`internalTemp`, `overHeat`, `powerSource`). Its `refresh` reads the primary, read-only, and user-set parameters; its `updated()` writes only parameters whose setting changed.
- **Group binding syntax already exists in that driver** (`bindGroup`): `zdo bind 0x<dni> 0x02 0x01 0x0006 {<switch ieee>} {<group id, 4 hex>}` and the same for `0x0008`, followed by a 60 s delay because the device acknowledges slowly. Unbind is the same with `zdo unbind`. This is the syntax to verify in the spike, not invent.
- **What `common` already does.** `ClustersMap` is the dispatch registry (a cluster absent from it is logged as unknown and never routed). `parseZdoClusters` logs ZDO bind responses (`0x8021`) and hands every ZDO frame to `customParseZdoClusters` if the driver defines it, which is where a binding-table response (`0x8033`) can be parsed. `updated()` calls `customUpdated()`; `configure()` calls `customConfigureDevice()` only if defined; `refresh()` uses `customRefresh()` as the whole command list.
- **The hub today.** `0xFC31` attribute reports for `0x0020`/`0x0021` (internal temperature, overheat) already arrive every minute from Hallway Switch because Inovelli's driver configured that reporting; on the 0.1.1 driver they surface as unknown-cluster warnings. Five Hubitat Group devices exist; three are `Group Bulb Dimmer-2.1`, the type the built-in Groups and Scenes app uses when Zigbee group messaging is on. A group device's data map is empty and its DNI is `Group_<n>`.
- **Home Assistant** reaches the hub through Maker API (app 28), which exposes capabilities and attributes and lets HA call any command.
- **No Groovy test runner exists**; `probe` and `push` are the compile checks and the specs' scenarios are the behavioural checks.

## Goals / Non-Goals

**Goals:**

- One verified unit: a switch in smart-bulb mode bound to a group its bulbs belong to, controlled from the paddle with the hub rebooting, with the switch's binding table read back as proof.
- A parameter surface that cannot silently reconfigure a device: reads populate preferences, saves write only deltas, Configure writes nothing.
- The `common` diff against upstream stays at one line.

**Non-Goals:**

- Scene-button events and LED effects (next change; this change only keeps their traffic quiet).
- A custom Hubitat app for units. The built-in Groups app owns bulb membership; if the spike shows its group id cannot be learned, that becomes a design question, not a silent fallback.
- Per-LED parameters (60–95), fan and aux parameters, Inovelli's `bindInitiator`/`bindTarget`, firmware update.

## Decisions

### D1. Units are group bindings, not unicast bindings or hub mirroring

Switch EP2 is bound to a 16-bit group for `0x0006` and `0x0008`; bulbs are members of that group. Two binding-table entries regardless of bulb count, one multicast per paddle action, no popcorn, and nothing in the path when the hub is down.
Rejected: unicast bindings per bulb (what the third-party app did: one entry per bulb per cluster, N sends, retries per unacked bulb, Hue endpoint `0x0B` easily got wrong), and hub-side mirroring of the switch level onto the bulbs (lag, and dead during an outage, which contradicts the unit's purpose).

### D2. Bulb membership comes from Hubitat's Groups and Scenes app with Zigbee group messaging

The app already puts bulbs into a Zigbee group and gives Home Assistant one light device per unit; three such groups exist. Bulbs keep their built-in drivers, which is also why no code of ours can send them group commands.
Open until the spike: how to learn the group id. The DNI `Group_<n>` is the lead; the test is binding the switch to that id and watching the bulbs. If the id is not discoverable, the alternatives are a parameter-free `bindGroup` that accepts the id read from a Zigbee sniff of a group command, or an `rbn` app that owns membership through a custom bulb driver — both out of this change and a reason to come back to design.

### D3. Binding commands are `bindGroup(groupId)`, `unbindGroup(groupId)`, `readBindings()`, plus a `bind(cmds)` relay

Each is one `sendZigbeeCommands` dispatch. `readBindings` sends a ZDO Mgmt_Bind_req (`0x0033`) and the driver parses the `0x8033` response in `customParseZdoClusters`: status, total entries, start index, count, then per entry the source IEEE, source endpoint, cluster, destination address mode, and a group id or an IEEE plus endpoint. Entries are emitted as a `bindings` attribute (JSON) and logged; if the total exceeds one frame, the next page is requested by start index. Read-back after every bind and unbind is what the spec's scenarios assert on, and the Inovelli parameter 51 (binding count, read-only) is the cross-check.
Rejected: Inovelli's device-driven finding-and-binding (`bindInitiator`/`bindTarget`), which needs the target in identify mode and does not bind to groups.

### D4. The parameter table is generated, keyed by number, and renders the preferences

A static map keyed by parameter number: name, size, type (`enum`, `number`, `bool`), a range _spec_ rather than an enumerated range (dimming and ramp parameters share one generator for 0 = instant, 5–126 in tenths of a second, 127 = sync-with-parameter-N; levels are 1–254 or 0–100 per Inovelli's scaling; enums list their options), default, `readOnly`, and a display group. The `preferences` block iterates the table, so adding a parameter is one table row. Inovelli's spelled-out enums are why their table is 900 lines; this one is a few dozen.
Setting names stay `parameter<N>` (unpadded), matching Inovelli's, so a device moved between the two drivers shows the same stored preferences and leaves no orphans; the first `refresh` overwrites them from the device either way (D5).
The in-scope set is the proposal's list; the table carries only those rows, not the full 103, so the preference page stays short and nothing unverified is offered.

### D5. Device is the source of truth: read on refresh, write deltas on save, Configure writes nothing

`customRefresh()` returns the four standard reads plus a read of every table parameter, as one list. Each `0xFC31` attribute report updates `settings.parameter<N>` and records the value in `state.parameters` (the last value the device confirmed); read-only parameters become attributes instead of settings. `customUpdated()` compares each editable preference with `state.parameters` and writes only the differences (with the longer delay for 52 and 258), then reads those back, so a write that the device rejects is visible as a preference that snaps back. No `customConfigureDevice()` is defined, so `configure` sends nothing on the private cluster and cannot reset a unit; reporting configuration stays as Inovelli's driver left it, as it has since 0.1.0.
A driver swap does not run `installed()` or `updated()`, so the README's first step after selecting the driver is `refresh`; until then the page may show stale settings from the previous driver.
Rejected: writing all preferences on save (Inovelli-style parameter bursts were the original complaint), and applying table defaults on `configure` (would undo a working unit at a click).

### D6. `common` gets one `ClustersMap` entry: `0xFC31: 'InovelliPrivate'`

The dispatcher then calls `customParseInovelliPrivateCluster(descMap)` in the driver. The parser handles attribute reports and read responses as parameters (D5); for cluster-specific commands (scene buttons, `descMap.isClusterSpecific`) it logs at debug and returns, which is the spec's "quiet" scenario. The provenance `Modified for the rbn namespace:` line in `common` names the added entry so the upstream diff stays explainable.
Rejected: handling `0xFC31` through `customParseDefaultCommandResponse` or an unknown-cluster hook — the rules say the map is the registry, and a one-line diff is the cheapest possible deviation from upstream.

### D7. Validation is one unit, rebooted mid-test

Candidate: Bathroom Light Switch (device 5) with the existing Zigbee-messaging group Bathroom Lights (device 37), both Hue bulbs. Protocol: record the switch's parameters and binding table on Inovelli's driver; select ours; `refresh`; confirm preferences match the recording; set smart-bulb mode on if it is not; `bindGroup` with the group id from the spike; `readBindings`; paddle test; reboot the hub; paddle test during the outage; after the hub returns, HA sets the group to 30 and the switch's power follows. Rollback at any point is `unbindGroup` plus reselecting Inovelli's driver.

### D8. Release as 0.2.0 through HPM

The parameter surface is new behaviour, so the minor version moves. HPM's update path was proven at 0.1.1; this is its first real payload.

## Risks / Trade-offs

- [The Groups app's group id cannot be learned] → The spike runs before any driver code; if it fails, stop and redesign D2 rather than ship bindings nobody can target.
- [A bulb replaced later is not in the group] → Documented procedure: add it to the Hubitat group (the app re-sends membership), then `readBindings` and a paddle test. The switch side needs nothing.
- [Hue bulbs receive the multicast but the switch's own state drifts from HA-side changes] → Accepted by the spec: hub-initiated light control targets the group, the switch reports the paddle. An HA automation can mirror level back to the switch; it is an HA concern.
- [Turning Zigbee group messaging off in the Groups app silently dissolves the unit] → README states it as the one setting that must stay on; `readBindings` still shows the switch half intact, which is the diagnostic.
- [Bind acknowledgements take up to 60 s] → The 60 s delay from Inovelli's driver is kept; the spec's proof is the read-back, not the acknowledgement timing.
- [Writing 52 or 258 mid-session makes the device reconfigure and drop a frame] → Longer delay for those two, and the read-back after write shows the result.
- [`settings` already holds Inovelli's values when the driver is first selected] → `refresh` overwrites them from the device; the README says to refresh first; nothing is written to the device until the user saves.
- [The parameter read on `refresh` is ~25 reads in one dispatch] → Still one `sendZigbeeCommands`; at Inovelli's short delay it is under ten seconds and only on explicit refresh.

## Migration Plan

1. Spikes on the hub, no repo change: group-bind syntax and read-back on one switch (on Inovelli's driver, which has `bindGroup`), and the Groups app's group id for Bathroom Lights.
2. Repo: `common` map entry, driver table, parsers, commands; `probe` and `push` compile checks; README and AGENTS; commit per group.
3. Hub: move Bathroom Light Switch onto the driver, run D7 end to end, record results.
4. Repo: bump to 0.2.0, release notes, commit; user pushes; HPM update.
5. Hub: roll the remaining units one at a time using the README procedure.
6. Rollback: `unbindGroup`, reselect Inovelli's driver; parameters are untouched unless deliberately saved.

## Open Questions

- Whether a future `rbn` app should own unit definitions once ten units exist. Deferrable; nothing here precludes it.
- Whether the third-party Zigbee Bindings app and its leftover unicast bindings should be cleaned off the switches during rollout (`readBindings` will show them). Deferrable; stale entries are inert but consume table space.
- Whether the LED-bar whole-bar parameters (96–100) belong here or with LED effects. Kept here because they are plain parameters; movable without changing the approach.
