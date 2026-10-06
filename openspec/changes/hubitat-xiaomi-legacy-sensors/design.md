## Context

See proposal.md for motivation.
Facts that shape the approach, read from the `rbn` libraries, the upstream checkout at `0bf47407` (`/Users/john/Documents/src/github.com/kkossev/Hubitat`), and the hub:

- **How the old-generation devices talk.**
  Neither model has a Power Configuration cluster (`0x0001`) or the new-generation `0xFCC0` cluster.
  Battery voltage arrives inside a vendor struct on the Basic cluster, attribute `0xFF01` (occasionally `0xFF02` on older Mijia firmware), sent on the device's own cadence — roughly hourly — and on a button press.
  The struct is a tag/type/value list: tag `0x01` type `0x21` is voltage in millivolts, `0x03` type `0x28` the internal temperature, `0x64` type `0x10` the magnet's contact state; the weather sensor also repeats temperature, humidity, and pressure as tags `0x64`–`0x66`.
  Contact is also sent as an ordinary On/Off cluster report (`0x0006:0x0000`, `01` = open) on every open and close; temperature, humidity, and pressure as `0x0402`, `0x0405`, `0x0403` attribute `0x0000` on the sensor's change-driven schedule.
  The devices are non-polling end devices: a read sent while they sleep is never delivered, and Configure Reporting is not honoured.
- **What the hub does to `0xFF01`.**
  The attribute is typed as a character string (`0x42`), and `zigbee.parseDescriptionAsMap` decodes a `0x42` value into characters, not hex.
  Upstream's Aqara contact driver fixes this by rewriting `01FF42` to `01FF41` in the description before parsing (octet string, value kept as hex); its P1 motion driver instead re-hexes the characters after the fact.
  `common.parse()` holds the raw description and already funnels it through `myParseDescriptionAsMap(description)`.
- **What `common` and `xiaomi` already have.**
  `standardParseBasicCluster(descMap)` records the check-in time, handles model/manufacturer/power-source/firmware attributes, and logs anything else at debug; the dispatcher calls `standardParseColorControlCluster` from a library via `respondsTo` for `0x0300`, which is the pattern for a library-provided handler `common` does not own.
  `xiaomi` has `decodeXiaomiTags(hex)` (the TLV reader used for `0xFCC0:0x00F7`) and `parseXiaomiClusterTags(tags)`, whose per-tag handler only logs voltage and only logs tag `0x64`; it also records parent NWK and firmware build from tags `0x0a` and `0x08`.
  `battery` has `sendBatteryVoltageEvent(rawTenthsOfAVolt, convertToPercent)` with a 2.2–3.2 V curve; the Cube sets `voltageToPercent` true in `customInitializeVars`.
  `common.refresh()` uses `customRefresh()` as the whole command list when defined, else collects `temperatureRefresh`, `humidityRefresh`, `batteryRefresh`, and friends by name.
  `configure()` sends only what `customConfigureDevice()`/`customInitializeDevice()` return.
- **Health status.**
  `parse()` marks the device online on any message; `deviceHealthCheck` runs on the `healthCheckInterval` preference (options 2, 10, 30, 60, 240, 720 minutes; default 240) and sets `offline` once `PRESENCE_COUNT_THRESHOLD = 3` consecutive checks have seen nothing.
  Method 1 is activity check; method 2 additionally pings, and a ping a sleeping device cannot answer counts as a failure.
  No check is scheduled until the preference has a settings row, and the hub creates rows only on the first Save Preferences after a driver is selected (verified on the VZM31-SN); `initializeVars()`'s `updateSetting` of the default is silently dropped before that.
- **Upstream has no pressure library** at this commit; its only `lumi.weather` code is the standalone waytotheweb driver, which treats `0x0403:0x0000` as an unsigned integer in hPa and ignores values outside 500–2000.
  It has `temperatureLib` (119 lines) and `humidityLib` (105 lines), neither Tuya-coupled; their min/max reporting preferences render only when `advancedOptions` is on **and** `'ReportingConfiguration' in DEVICE?.capabilities`, where `DEVICE` is a device-profile object no `rbn` driver defines — the same guard `battery` uses for its delay option, which the Cube proved renders as absent.
- **The tree today**: `just hubitat check` fails only on `btf-lighting-lm052`, the sibling change's stub, which is not touched here; the two misnamed Aqara stubs were removed by hand on 2026-10-06.

## Goals / Non-Goals

**Goals:**

- A sensor that stops checking in, for whatever reason, becomes `healthStatus: offline` within a few hours, visible to Home Assistant through Maker API as a state distinct from a low battery.
- Battery voltage and percentage, pressure, and contact-from-struct come from shared library code that the next old-generation Xiaomi device (motion, leak, button) can reuse without touching `common` again.
- `common`'s diff against upstream grows by three explainable hunks and no vendor logic.

**Non-Goals:**

- Decoding the weather sensor's duplicate tags (`0x64`–`0x66`) or the internal-temperature tag `0x03`; the standard clusters are the source and upstream gates the internal temperature behind an "experimental" switch for a reason.
- Reporting configuration or binding commands for these devices; they accept neither.
- A pressure library, a `0xFF02` decoder beyond the voltage field, or support for any device not in the four.
- Changing `battery`'s voltage-to-percent curve.

## Decisions

### D1. Directories `aqara-wsdcgq11lm` and `aqara-mccgq11lm`; names `Aqara Temperature and Humidity Sensor (WSDCGQ11LM)` and `Aqara Door and Window Sensor (MCCGQ11LM)`

The directory is a path and follows the terse `vendor-model` form of `aqara-cube-t1-pro` and `inovelli-vzm31-sn`; the display name is what the Type dropdown and HPM show and leads with what a person remembers, model in parentheses, as the VZM31-SN does.
The product names are Aqara's own ("Temperature and Humidity Sensor", "Door and Window Sensor"), so the words are the ones a search will match.
The seller's code `T007` names nothing in the device, the fingerprint, or any Zigbee database and is not used anywhere.
Rejected: the long `aqara-door-window-sensor-mccgq11lm` form (repeats the display name in a path), and the Zigbee model strings as names (`lumi.weather` is what a fingerprint matches, not what anyone looks for).

### D2. The `0xFF01` decoder lives in `xiaomi`; `common` only routes to it

`common.standardParseBasicCluster` gains one `case` for `0xFF01`/`0xFF02` that calls `parseXiaomiLegacyStruct(descMap)` when `respondsTo` finds it, otherwise logs at debug as before.
The function lives in `xiaomi`, where the vendor's TLV reader and tag table already are: it strips nothing it does not have to, runs `decodeXiaomiTags`, emits battery from tag `0x01`, runs the existing `parseXiaomiClusterTags` for the bookkeeping tags, and then calls `customParseXiaomiLegacyTags(tags)` if the driver defines it, which is where the contact driver reads tag `0x64`.
`battery` is reached through `respondsTo('sendBatteryVoltageEvent')` because libraries cannot include libraries; a driver on `xiaomi` without `battery` gets a debug line, not an error.
This mirrors how `0x0300` is routed to a library-provided `standardParseColorControlCluster` today and keeps `common` free of vendor code.
Rejected: the decoder in `common` (it is the Tuya-stripped core; vendor structs belong in the vendor library), and a per-driver `customParseBasicCluster` (it replaces the standard parser wholesale, so each driver would re-implement the check-in bookkeeping and the decoder twice).

### D3. The character-string type is normalised in `myParseDescriptionAsMap`, before the hub parses

`common.myParseDescriptionAsMap` rewrites `01FF42` to `01FF41` (and `02FF42` to `02FF41`) in the description before `zigbee.parseDescriptionAsMap`, gated on `isAqara()` so no other vendor's `0xFF01` is touched.
It is upstream's own proven fix (Aqara contact driver), one line, and it means `descMap.value` is hex for every downstream consumer rather than each consumer re-hexing characters.
The first hub task confirms what the hub actually hands over (hex, and whether the string's length byte is present) from the debug `parse: descMap =` line and adjusts the decoder's offset accordingly — the waytotheweb driver's indexing suggests a leading length byte, the `0xFCC0` path suggests none.
Rejected: re-hexing characters in the decoder (the P1 approach) — it works, but it leaves the mangled value in `descMap` for anything else that logs or inspects it, and the two approaches can coexist as a fallback if the spike shows the rewrite does not reach the hub's parser.

### D4. Pressure is driver code, not a library

`0x0403: 'Pressure'` goes into `ClustersMap` (required regardless — unmapped clusters are never dispatched) and the weather driver owns `customParsePressureCluster(descMap)`: attribute `0x0000` as an unsigned integer in hPa, ignored outside 500–2000, emitted as `pressure`; other attributes (`0x0010` scaled value, `0x0014` scale) logged at debug.
There is exactly one consumer, upstream has nothing to fork, and the VZM31-SN's metering overrides set the precedent that device glue beside shared parsing is the architecture's intended use.
Rejected: a `pressure` library — a second consumer is the moment to extract it, and extracting later changes no behaviour.

### D5. `temperature` and `humidity` are forked identity-only; reporting preferences are suppressed by the fork's structure, not by code

Both libraries are copied at `0bf47407` with the Apache header kept, the provenance block added, `name` and `namespace` set, `importUrl` cleared, nothing else.
Their `minReportingTime`/`maxReportingTime` inputs do not render because the `DEVICE?.capabilities` guard is never satisfied in an `rbn` driver, and nothing in `common` calls their `*LibInitializeDevice()` reporting-configuration helpers, so no Configure Reporting command is ever built for these devices.
The scenario that checks this is "the preference page shows the offsets and not the reporting intervals, and `configure` sends nothing".
Rejected: editing the forks to delete those inputs (a diff against upstream for a condition that is already false), and a driver-level `DEVICE` definition (would start pulling in device-profile semantics).

### D6. The contact driver does not include `switch`; it owns `customParseOnOffCluster`

Including `switch` would declare `Switch` and `Actuator`, offer `on`/`off` commands the magnet cannot take, and emit `switch` events for a door.
The driver declares `ContactSensor` and parses `0x0006:0x0000` itself (`01` → `open`, `00` → `closed`); the dispatcher prefers `customParse<Name>Cluster`, so no standard handler is needed and none is included.
The hourly struct's tag `0x64` feeds the same `contact` event through `customParseXiaomiLegacyTags`, so a missed On/Off report is corrected within the hour.
Rejected: including `switch` and mapping `switch` to `contact` afterwards (two events and two capabilities for one fact).

### D7. Health check: activity method, 1-hour interval, set in the Save Preferences the swap already needs

Reads are never answered while the device sleeps, so method 2 (polling) would count every ping as a failure and declare a healthy device offline; the drivers rely on method 1 (activity), which `parse()` feeds from any message.
With an hourly check-in, a 1-hour interval and the library's threshold of 3 mean `offline` between three and four hours after the last message; the default 4 hours would mean 12–16.
`customInitializeVars(fullInit)` writes 60 on a full initialisation (pairing by fingerprint, Load All Defaults).
On a driver swap `installed()` does not run and no settings row exists until the operator saves preferences once — which they must do anyway for any check to be scheduled — so the README's procedure is "select the driver, set Healthcheck Interval to Every 1 Hour, Save Preferences, refresh", and the log line `scheduling health check every 60 minutes by Activity check method` is the proof.
Rejected: a code path that overrides a saved 240 (would fight a deliberate choice), and the 30-minute option (a sensor on a 50–60-minute cadence would trip the counter on quiet hours and flap).

### D8. `refresh` is one dispatch of the standard reads; `configure` sends nothing

Weather: `customRefresh()` returns reads of `0x0402`, `0x0403`, `0x0405` attribute `0x0000`; contact: a read of `0x0006:0x0000`.
Defining `customRefresh` also keeps `batteryRefresh` out of the list, which would read a `0x0001` cluster neither device has.
The reads are answered only if the device is awake — in practice within a second or two of a button press — and otherwise produce the library's 10-second "no response received (sleepy device or offline?)" warning, which the README names as expected.
No `customConfigureDevice`/`customInitializeDevice`: there is no reporting to configure and no binding the devices need, so `configure` logs "no commands defined" as the VZM31-SN 0.1.x did.
Rejected: omitting `customRefresh` on the contact driver (then `refresh` sends `batteryRefresh`'s unanswerable read and nothing useful).

### D9. `DEVICE_TYPE` is `THSensor` and `ContactSensor`; `voltageToPercent` is on

The libraries branch on `DEVICE_TYPE` only for `Thermostat`, `Bulb`, `AqaraCube`, `mmWaveSensor`, `TRV`, and `Device`; any other string is inert, so these two name the device class and nothing more.
`customInitializeVars` sets `voltageToPercent` true as the Cube does, so a struct report yields both `batteryVoltage` and `battery`; the decoder converts millivolts to the tenths-of-a-volt `sendBatteryVoltageEvent` expects, and the shared 2.2–3.2 V curve applies (a fresh CR2032 at 3.0 V reads 80 %).

### D10. Both drivers start at `0.1.0`; the post-validation bump is `0.1.1`; Cube and VZM31-SN manifests are not bumped

The VZM31-SN set the pattern: `0.1.0` is the authored driver, `0.1.1` "runtime validated on hardware" is the first HPM release.
The Cube and VZM31-SN bundles regenerate because `common` and `xiaomi` are inlined into them, but their behaviour is unchanged (`0xFF01` never arrives on those devices), so their manifests keep their versions, as the `0xFC31` map entry did in `hubitat-vzm31-sn-unit`.

### D11. Commits land per task group

One for the library routing (`common`, `xiaomi`, the two regenerated bundles), one for the two forked libraries with their README attribution rows, one for the drivers with manifests, index, and bundles, one for docs, one for the release bump, one for the openspec record; hub-only groups produce no commit.
`just hubitat check` and `nix fmt` precede every commit; the fileset is explicit because the sibling change shares the workspace.

## Risks / Trade-offs

- [The `01FF42` rewrite does not take, and `descMap.value` arrives as characters] → The first hub task reads the debug `descMap` line before any decoder logic is trusted; the fallback is the P1 re-hex inside `parseXiaomiLegacyStruct`, a few lines, with the rewrite left in place.
- [A leading length byte shifts every tag by one] → Same spike; the decoder strips the first byte only if the spike shows it is there, and the battery scenario's voltage (a plausible 2.8–3.1 V) is the check.
- [`isAqara()` gating misses a device whose `model` data value is empty] → The four devices all carry `lumi.*` models today; a device without one would not match the fingerprint either.
- [The weather sensor also carries temperature/humidity/pressure tags in the struct and could double-emit] → The weather driver defines no `customParseXiaomiLegacyTags`; those tags only reach the existing debug logger.
- [Health check declares a quiet-but-alive sensor offline] → The threshold is three consecutive misses at the device's own cadence; a single late report resets the counter on arrival, and `online` returns on the next message with no operator action.
- [The operator skips Save Preferences after the swap] → No health check is scheduled, and the device behaves exactly as on the built-in driver — no worse, and the README says why the step exists.
- [`refresh` on a sleeping device logs a warning that looks like a fault] → Documented as expected; it never affects `healthStatus` under method 1.
- [Concurrent edits to `common` from `hubitat-color-lights`] → Named in the proposal's Impact; one map entry and one provenance clause, re-applied by whoever lands second, bundles regenerated rather than merged.

## Migration Plan

1. Repo: `common` routing and normalisation, `xiaomi` decoder; fork `temperature` and `humidity`; `probe` compiles everything; commit.
2. Repo: the two drivers with manifests, index entries, bundles; `check` green; commit.
3. Hub, spike with the real device: `just hubitat push aqara-mccgq11lm`, move one contact sensor, press its button, read the `descMap` line for `0xFF01`; adjust the decoder if needed, re-push.
4. Hub, validation per D7/D8 on one contact sensor, then the weather sensor; rollback at any step is the built-in driver.
5. Repo: README rows and operator section, AGENTS rules; commit.
6. Repo: bump both drivers to `0.1.1`; commit; user pushes; HPM Match Up adopts both (they reached the hub by `push`).
7. Hub: the remaining two contact sensors, one at a time, each with a Save Preferences and an open/close.

## Open Questions

- Whether a future old-generation Xiaomi device (motion `lumi.sensor_motion.aq2`, leak `lumi.sensor_wleak.aq1`, button `lumi.sensor_switch.aq2`) warrants moving the per-tag `custom*` hook into a small shared table in `xiaomi`.
  Deferrable; the hook is the extension point either way.
- Whether `battery`'s 2.2–3.2 V curve should become a per-driver range (upstream's P1 uses 2.5–3.0 for coin cells).
  Deferrable; it changes a number, not an interface, and the Cube would change with it.
- Whether the Cube's and VZM31-SN's HPM packages should be re-released when their inlined libraries change without behavioural effect.
  Deferrable; the next real release of each carries the new library code regardless.
