## Why

Four old-generation Xiaomi sensors sit on Hubitat's built-in drivers: an Aqara WSDCGQ11LM temperature/humidity/pressure sensor (`lumi.weather`, device 28) and three Aqara MCCGQ11LM door/window sensors (`lumi.sensor_magnet.aq2`, devices 26, 27, 33).
The weather sensor went silent on 2026-08-29 with a dead CR2032 and was revived on 2026-10-06; the built-in driver had reported the low battery and Home Assistant showed it, so the delay was a deferred chore, not an invisible failure.
What the built-in driver cannot say is that the device has stopped checking in at all: a low battery and a device that is gone are different facts, and only the second one covers a drop-off, a dead parent router, or a cell that dies without a low reading first.
The `rbn` libraries already carry the health-status machinery that turns silence into an `offline` state, but they cannot run these devices today: the Xiaomi `0xFF01` struct that carries their battery voltage falls through `common`'s Basic-cluster parser as unknown, cluster `0x0403` (pressure) is absent from `ClustersMap`, and there is no temperature or humidity library in the fork at all.
These are sleepy, report-only sensors with no commands to map, so the gains are modest and should be stated as such: battery voltage and percentage from the struct, pressure, and an `offline` that fires within hours instead of never.

## What Changes

- **`common` learns two things, both one-hunk and provenance-noted**: `ClustersMap` gains `0x0403: 'Pressure'` (the registry rule: an unmapped cluster is never dispatched), and the Basic-cluster parser hands attributes `0xFF01`/`0xFF02` to a `xiaomi`-provided decoder when one is present, the way it already hands `0x0300` to `standardParseColorControlCluster`.
  Because the devices send `0xFF01` typed as a character string (`0x42`) rather than the octet string it is, the description is normalised to `0x41` before the hub parses it — the fix upstream's own Aqara contact driver uses — so the value stays hex.
- **`xiaomi` gains the legacy-struct decoder**: it reuses the library's existing TLV reader (the `0xFCC0` `0x00F7` struct has the same tag/type/value layout), emits `batteryVoltage` and `battery` through the `battery` library from tag `0x01` (millivolts), keeps the existing per-tag bookkeeping (parent NWK, firmware build), and offers the remaining tags to the driver through a `custom*` hook.
  Its provenance changes from "identity only" to naming the decoder, and the README row with it.
- **Two libraries forked identity-only from upstream**: `temperature` (`Libraries/temperatureLib.groovy`) and `humidity` (`Libraries/humidityLib.groovy`), at the same commit `0bf47407` as the rest; `common.refresh()` already names their refresh handlers.
  Their min/max reporting-interval preferences are gated on a device-profile capability no `rbn` driver declares, so they never render for these devices and nothing is ever written to a device that cannot accept reporting configuration.
- **Two drivers, versioned from `0.1.0`**: `hubitat/drivers/aqara-wsdcgq11lm/` (`Aqara Temperature and Humidity Sensor (WSDCGQ11LM)`, on `common`, `xiaomi`, `battery`, `temperature`, `humidity`, with pressure parsed in the driver) and `hubitat/drivers/aqara-mccgq11lm/` (`Aqara Door and Window Sensor (MCCGQ11LM)`, on `common`, `xiaomi`, `battery`, emitting `contact` from the On/Off cluster through its own parser rather than including `switch`, which would turn a magnet into a switch with commands it cannot take).
  Each declares the upstream fingerprint, a one-dispatch `refresh`, no `configure` payload, and a 1-hour default health-check interval chosen from the devices' own check-in cadence.
- **Packaging**: a `packageManifest.json` per driver with a fresh `uuidgen` id, two entries in `hubitat/repository.json`, committed bundles for both new drivers and regenerated bundles for the Cube and the VZM31-SN (whose inlined `common`/`xiaomi` change; their manifests are not bumped, since nothing they do changes).
- **Documentation**: README validation-status rows for `temperature` and `humidity`, the dated paragraph of what this run exercised, attribution rows for both forks, a short operator section (the one Save Preferences the driver swap needs, with the health interval set in it); `hubitat/AGENTS.md` gains the durable rules (legacy struct routing, the `0x42` normalisation, sleepy-device limits on refresh and health-check method).
- **Validation on the hub**, one device at a time with the built-in driver as rollback: contact open/close, battery voltage and percent from the hourly struct, temperature/humidity/pressure with offsets, `healthStatus: offline` after the threshold with the battery pulled, and one `sendZigbeeCommands` line per refresh — recording what cannot be observed (a sleeping device ignores reads).

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `hubitat-drivers`: gains requirements for pressure-cluster dispatch, decoding of the legacy Xiaomi `0xFF01` struct into battery events, contact derived from the On/Off cluster without a `switch` capability, the two drivers' identity and fingerprints, health status for check-in-only devices, and the validation-status rows for the two new libraries.
  No existing requirement is modified.

## Impact

- **Hub-side, four sensors over time**: each is moved from its built-in driver to ours; rollback at any point is reselecting the built-in driver, which loses nothing because these devices hold no configuration.
  Until a device next checks in on its own (roughly hourly) the new driver shows no battery; temperature, humidity, and pressure arrive on the sensor's own change-driven cadence, and contact on the next open or close.
- **Hub-side, the Cube and the ten dimmers**: untouched in behaviour; their hub copies change only if `just hubitat push` is run for them, and the probe-compiled libraries are the same code either way.
- **Repo**: `common` +3 small hunks, `xiaomi` +1 function and a hook, two new libraries, two new driver directories, two JSON manifests, two index entries, four regenerated bundles, README and AGENTS; no Nix, no CI, no Python change (`check` already enforces manifests and bundles).
- **Merge touchpoint with `hubitat-color-lights`**: that change also edits `common`'s `ClustersMap` literal (at `0x0300`) and the same `Modified for the rbn namespace:` provenance line, and both regenerate the Cube and VZM31-SN bundles.
  Whichever lands second re-applies one map entry and one provenance clause by hand and runs `just hubitat bundle`; a bundle is never merged textually.
  Nothing else overlaps.
- **Not touched**: `0xFF02` beyond its battery field, the weather sensor's duplicate temperature/humidity/pressure tags inside the struct (the standard clusters are the source), the `voltageToPercent` curve in `battery` (2.2–3.2 V, shared with the Cube), newer Aqara models on `0xFCC0`, any pressure library.
