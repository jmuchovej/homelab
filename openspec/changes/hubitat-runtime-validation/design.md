## Context

See proposal.md for motivation.
Facts that shape the approach, verified against the forked libraries, Inovelli's driver, and HPM 1.9.12's source:

- **What the libraries already give a dimmer driver.**
  `switch` declares `Actuator` and `Switch` and owns `standardParseOnOffCluster`, `on()`, `off()`.
  `level` declares `Switch`, `SwitchLevel`, `ChangeLevel`, owns `standardParseLevelControlCluster`, `setLevel`, `startLevelChange`/`stopLevelChange`, and provides `levelRefresh()` (on/off + level reads), which `common`'s `refresh()` picks up by name.
  `meter` declares `PowerMeter`, `EnergyMeter`, `VoltageMeasurement`, `CurrentMeter` and owns `standardParseMeteringCluster` / `standardParseElectricalMeasureCluster`, but has **no refresh handler** (its header's TODO says so) and `common`'s handler list does not name one.
- **Metering scale mismatch.**
  `meter` hardcodes energy `÷10` (`standardParseMeteringCluster`, with the `÷1000` commented out) and power `÷1`.
  Inovelli's driver scales energy `÷100` and power `÷10` (`inovelli-dimmer-blue-series-VZM31-SN.groovy:1299,1325`).
  The dispatcher prefers `customParse<Name>Cluster` over the standard one, so a driver can own exactly those two attributes.
- **Fingerprints.**
  Two endpoints: EP01 `inClusters 0000,0003,0004,0005,0006,0008,0702,0B04,0B05,FC57,FC31`, EP02 `inClusters 0000,0003` with `outClusters 0003,0019,0006,0008`, both `model VZM31-SN manufacturer Inovelli`.
- **`DEVICE_TYPE` matters.**
  `switch` and `level` gate preferences on `DEVICE_TYPE != 'Device'`; `switch` has `_THREE_STATE = true` with its option under `advancedOptions`.
- **Reporting is device state.**
  Inovelli's `updated()` issues `configureReporting` for `0x0B04:0x050B` and `0x0702:0x0000` from user parameters.
  `common`'s `configure()` runs `customConfigureDevice()`; if the minimal driver defines none, Configure sends nothing beyond `aqaraBlackMagic()` (a no-op without `customAqaraBlackMagic`).
  Still, not pressing Configure during the test removes the question entirely.
- **HPM.**
  Manifest keys read: `packageName`, `version`, `betaVersion`, `minimumHEVersion`, `releaseNotes`, `apps`, `drivers`, `bundles`, `files`, `licenseFile`.
  Driver entry keys: `id`, `name`, `namespace`, `location`, `required`, `version`.
  No `libraries` key exists anywhere.
  Install = GET `location`, POST `/driver/save`.
  Update detection = `newVersionAvailable()` comparing the manifest `version` string to the one recorded at install.
  Categories/tags are validated against `hubitat-packagerepositories/settings.json` (categories `Control`, `Convenience`, `Integrations`, `Notifications`, `Security`, `Utility`; tags include `Zigbee`, `Buttons`, `Lights & Switches`, `Energy Monitoring`).
  `repository.json` is `{author, gitHubUrl, payPalUrl, packages:[{id, name, category, location, description, tags}]}`.
  HPM's Match Up adopts code already on the hub by name+namespace so it can be managed without reinstalling.
- **Repo state.**
  `hubitat-rbn-libraries` is applied and split into per-group commits; its hub tasks (save libraries, probe, save Cube bundle) are the user's.
  `hubitat-cli` turned the bundler into the `hubitat` Python package (`hubitat/bundle.py`, `manifest.py`, `hub.py`, `push.py`, `bump.py`); `just hubitat bundle|check|push|probe|bump` are its commands.
  `uuidgen` is available.

## Goals / Non-Goals

**Goals:**

- Put `common`, `switch`, `level`, `meter`, `reporting` on a real device and observe the three things the fork claims: one dispatch per refresh, a Tuya-free parse path, and correct standard-cluster behaviour.
- A VZM31-SN driver whose name, directory, and HPM identity are the ones the full driver will keep, so the full driver is an update.
- HPM install and update paths proven on the hub, with a repo-side guard that makes manifest drift impossible to commit unnoticed.

**Non-Goals:**

- Any `0xFC31` handling, parameters, LED notifications, scene buttons, or fan mode.
  That is the full VZM31-SN change.
- Fixing `meter`'s hardcoded scales in the library (would need divisor-attribute support to be correct generally; the two-line override is the right size for now).
- Generating manifests from source.
  Hand-maintained plus the check is enough for two drivers.
- Making the Cube pair.
  Guidance is recorded; the tasks are gated.

## Decisions

### D1. The minimal driver carries the full driver's identity: directory `inovelli-vzm31-sn`, name `Inovelli Dimmer (Blue, VZM31-SN)`, namespace `rbn`

The display name is what the hub's Type dropdown and HPM's list show, so it leads with what a person remembers (an Inovelli Blue-series dimmer) and keeps the model code in parentheses for anyone matching a fingerprint.
The directory and bundle keep the terse `inovelli-vzm31-sn` identifier, which is a path, not a label.
HPM keys packages and drivers on UUID `id`, and the hub keys installed code on name+namespace.
Choosing the final identity now means the full driver ships as a version bump and HPM updates it in place; choosing a "basic" name would strand an installed package.
The driver's `version()` starts at `0.1.0` and the manifest matches; the first bump (`0.1.1`, "runtime validated on hardware") is itself the HPM update-detection test.

### D2. Metering scale is corrected in the driver with two `customParse*` overrides, not in `meter`

`customParseMeteringCluster` handles `attrId 0000` as `value ÷ 100` → `sendEnergyEvent`, and `customParseElectricalMeasureCluster` handles `attrId 050B` as `value ÷ 10` → `sendPowerEvent`; everything else in each falls through to the library's standard parser.
This is the architecture's intended use (device glue beside shared parsing) and keeps the library diff against upstream at zero for `meter`.
Alternative rejected: honouring the ZCL multiplier/divisor attributes in `meter` — correct in principle, but it changes behaviour for every future device and needs the device to actually report those attributes; out of scope.

### D3. `customRefresh()` is the dispatch under test

Because `meter` has no refresh handler, the driver defines `customRefresh()` returning one list: `zigbee.onOffRefresh()`, `zigbee.levelRefresh()`, `zigbee.readAttribute(0x0702, 0x0000)`, `zigbee.readAttribute(0x0B04, 0x050B)`.
`common.refresh()` passes that list to `sendZigbeeCommands()` once.
The spec scenario checks exactly one `sendZigbeeCommands: sent cmd=` line containing all four reads — the direct contrast with Inovelli's one-dispatch-per-attribute `refresh()`.

### D4. Configure is never invoked during validation; rollback is a driver reselect

Swapping a device's driver does not run `installed()` or `configure()`.
The protocol is: select the `rbn` driver, Save Device, refresh, operate, observe, reselect Inovelli's driver.
Inovelli's parameters live on the device and its driver's preferences stay in the device's settings map, so nothing needs re-entering; "Save Preferences" on the way back is explicitly _not_ pressed, since Inovelli's `updated()` would then fire its per-parameter write burst for no reason.
The minimal driver defines no `customConfigureDevice()`, so even an accidental Configure sends nothing to the device.

### D5. Manifests are hand-maintained; `manifest.py` (via `check`) validates them

`hubitat-cli` delivered the models and checks in `hubitat/manifest.py` (`check_manifest`, `check_repository`, run by the module's `check` command and covered by `hubitat/tests/test_manifest.py`); this change supplies the manifests themselves and tightens the check to require one per driver.
For each driver source, if `packageManifest.json` exists beside it the check parses it and asserts: `version == version()` parsed from the source's `static String version()` line; exactly one `drivers[]` entry; `namespace == 'rbn'`; `name ==` the `definition(name: …)` value; `location` ends with `/hubitat/drivers/<driver>/<driver>.bundled.groovy`; `id` is a UUID.
If `hubitat/repository.json` exists it asserts every `packages[].location` ends with a manifest path that exists, every manifest in the tree is listed, and `category`/`tags` are non-empty.
Failures name the file and exit 1, same as bundle drift.
Generating manifests was considered and rejected for now: with two drivers the hand-maintained form plus this guard is simpler, and generation can be added behind the same check later.
A manifest is required for every driver (the check fails if one is missing) so the tree never half-supports HPM.

### D6. One `repository.json`, added once; the hand-saved Cube is adopted via Match Up first

Order on the hub: run HPM Match Up so the Cube driver saved by hand in the previous change becomes HPM-managed; install the VZM31-SN package via Install → From a URL (proves that path); add `repository.json` as a custom repository (proves listing); after the `0.1.1` bump is pushed, run Update (proves detection).
Doing Match Up first avoids HPM offering a duplicate Cube install.

### D7. Package and id conventions

`packageName` in the manifest and `packages[].name` in the index are identical to the driver's display name, with no namespace tag: HPM renders every package card as `<name> by <author>` (`renderPackageButton`, `author` from `repository.json`) and offers sort-by-author, so the author is what distinguishes this `Aqara Cube T1 Pro` from kkossev's.
HPM never displays a driver's namespace; it uses it only for Match Up.
The one place two same-named drivers do collide is the hub's own Type dropdown, which shows names without namespaces — the remedy there is not to keep kkossev's Cube driver installed alongside ours, not to tag names.
Each manifest and each index entry gets a UUID from `uuidgen` at creation and the ids are recorded nowhere else; `AGENTS.md` states they are permanent.
`author` is the repo owner; `minimumHEVersion` is `2.3.6.0` (what the Cube's upstream manifest declares and the oldest the libraries are known to run on); `documentationLink` points at `hubitat/README.md` on GitHub.
Categories: `Control` for both; tags `Zigbee` + `Buttons` (Cube) and `Zigbee` + `Lights & Switches` + `Energy Monitoring` (VZM31-SN).

### D8. README carries a per-library status matrix

A table: library → status (`runtime-verified` / `compile-verified`) → device → date.
It replaces the single "compile-verified only" paragraph and is what the spec's status requirement reads.
The Cube rows flip only when the gated tasks run.

### D9. Cube tasks are gated, and the change can archive with them open

The gated tasks are written as real, checkable steps so that the day a Cube pairs there is nothing to plan.
If it has not paired when the rest is done, those tasks are marked with the reason and the change is archived; the README status matrix already says those three libraries are compile-verified only, so nothing is overstated.

### D10. Commits land per task group

As agreed after the previous change: one commit for the driver, one for HPM packaging and the check, one for docs, one for the openspec record; hub-only groups produce no commit.

## Risks / Trade-offs

- [The minimal driver misbehaves on the dimmer] → That is the point of the exercise; the device is reselected onto Inovelli's driver and the finding is recorded against the library, not papered over in the driver.
- [`meter` emits `voltage`/`amperage` attributes the device never reports] → Cosmetic: capabilities come from the library.
  Noted in the driver header; the full driver decides whether to keep `meter` or a trimmed include.
- [A stray Configure during the test] → Sends nothing, by D4.
  Reporting intervals are only at risk if someone then also saves preferences on Inovelli's driver afterwards, which the protocol forbids.
- [HPM Match Up picks the wrong code] → Match Up lists candidates by name+namespace; `rbn` is unique on the hub, so the only `Aqara Cube T1 Pro` in `rbn` is ours.
- [Two `Aqara Cube T1 Pro` entries in the hub's Type dropdown] → Only if kkossev's driver is still installed; the dropdown shows names without namespaces.
  Remove kkossev's Cube driver from the hub once ours is confirmed (tracked as an open question in `hubitat-rbn-libraries`).
- [Update-detection test needs a real push] → Accepted; the `0.1.1` bump is a genuine release ("runtime validated") and the user pushes anyway.
- [Manifest check is only as good as the `version()` regex] → The regex is anchored to the `static String version()` line the repo convention mandates; a driver without it fails the check loudly.

## Migration Plan

1. Preconditions: `hubitat-rbn-libraries` hub tasks done; its commits pushed; the raw bundle URL for the Cube returns 200.
2. Repo: driver, bundle, manifests, index, check extension, docs; `just hubitat check` clean; commits per group; push.
3. Hub, HPM: Match Up the Cube; Install → From a URL with the VZM31-SN manifest; add `repository.json` as a custom repository; confirm both packages listed.
4. Hub, validation on one dimmer (debug logging on): reselect driver → Save Device → `refresh` → on/off/`setLevel` from the page → paddle up/down/hold → wait for one power and one energy report → double-tap once → reselect Inovelli's driver.
   No Configure, no Save Preferences on the way back.
   Record log excerpts.
5. Repo: README status matrix and any findings; bump `version()` and manifest to `0.1.1`; re-bundle; commit; push.
6. Hub: HPM Update shows `Inovelli Dimmer (Blue, VZM31-SN)` 0.1.1; update it.
7. Rollback at any point: reselect Inovelli's driver; HPM-installed code can be removed through HPM.

## Open Questions

- Whether the full VZM31-SN driver keeps `meter` as-is with the two overrides or the library grows divisor-attribute support.
  Deferrable; the override is correct for this device either way.
- Whether `repository.json` should eventually be listed in HPM's public repository index (`hubitat-packagerepositories`).
  Deferrable and probably no: it is a single-user tree.
