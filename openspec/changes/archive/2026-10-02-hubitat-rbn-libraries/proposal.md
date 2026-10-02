## Why

The Hubitat drivers this repo carries are five verbatim copies of other people's monoliths under `hubitat/`, and the one that matters most is defective by construction: Inovelli's official VZM31-SN driver dispatches one `sendHubCommand` per attribute, so a single Refresh fires 20–65 hub commands back to back and the hub throttles.
kkossev's library architecture fixes that structurally (`sendZigbeeCommands()` batches a whole command list into one `HubMultiAction`; `standardAndCustomParseCluster()` lets a driver own only the clusters where its device is odd), but it cannot be built on in place: its `commonLib.parse()` runs two Tuya pre-parsers on every message (`+15 ms` by its own annotation) for devices that will never speak Tuya, the private cluster an Inovelli driver needs (`0xFC31`) is absent from its dispatch table and cannot be added from a driver, and any local edit to a `kkossev.*` library is silently reverted by the next HPM update.
Forking the libraries into the repo's own `rbn` namespace is the prerequisite for every driver that follows; doing it now, proven to compile on the hub, means the VZM31-SN driver starts from a Tuya-free base rather than from a 3,563-line file.
Runtime validation on hardware is deliberately a separate, following change: the Aqara Cube T1 Pro is not currently paired (its join fails before any driver is selected), and the only paired candidates are the Inovelli dimmers, which have no `rbn` driver yet.

## What Changes

- Add a `hubitat/libraries/` tree holding eight libraries forked from `kkossev/Hubitat@0bf47407` (`Libraries/*.groovy`) into namespace `rbn`, with each file keeping its original Apache-2.0 header and gaining a modification notice: `common`, `switch`, `xiaomi`, `button`, `battery` (the five the Cube includes), plus `level`, `meter`, `reporting` (pure ZCL, zero Tuya references, needed by the VZM31-SN driver).
  Names are the bare domain word — the `libraries/` directory already says what they are, so the upstream `Lib` suffix goes — `onOffLib` becomes `switch`, the Hubitat capability it implements (cluster `0x0006` only; dimming is `level`), and `energyLib` becomes `meter`, since it implements `PowerMeter`, `EnergyMeter`, `VoltageMeasurement`, and `CurrentMeter` rather than energy alone.
  `deviceProfileLibV4` is **not** forked here: it is 2,623 lines whose conversion core is Tuya-datapoint shaped, and there is no driver in this change to compile it against; that decision belongs to the VZM31-SN change.
- Strip the Tuya code path from `common`, `switch`, and `battery`: the two per-message pre-parsers and their call in `parse()`, the `0xEF00` cluster handler chain, the Tuya command builders and constants, `tuyaBlackMagic()`/`queryAllTuyaDP()`/`updateTuyaVersion()`/`isTuya()` and their call sites in `configure()`, `initialize()`, and `checkDriverVersion()`, the `_DEBUG`-gated `tuyaTest` command, the Tuya-cluster entries in `ClustersMap`, and the `isTuya()` branches in `switch` and `battery`.
  Everything Aqara (`aqaraBlackMagic()`, `updateAqaraVersion()`, `isAqara()`, `xiaomi`) stays — the Cube depends on it.
- Port the Aqara Cube T1 Pro driver to the fork as `hubitat/drivers/aqara-cube-t1-pro/aqara-cube-t1-pro.groovy` (`#include rbn.*`, `namespace: 'rbn'`, `importUrl` pointing at this repo's generated bundle) and delete the vendored `hubitat/drivers/aqara-cube-t1-pro.groovy` it replaces.
  Only the includes and identity change.
  The port is verified by saving its bundle on the hub (which compiles five of the eight libraries); its behaviour on a paired Cube is out of scope until one pairs.
- Add a bundler that generates `<driver>.bundled.groovy` from a driver source and its `#include rbn.<name>` lines — the single-file artifact the hub imports by URL — reproducing upstream's start/end and per-line `library marker` comments so compile errors in the bundle map back to library lines.
  Upstream has no such tool; regeneration there is manual copy-paste.
- Add `hubitat/justfile` as a root `just` module (`just hubitat bundle`, `just hubitat check` for drift) and `hubitat/README.md` with the attribution notice.
- Add `hubitat/AGENTS.md` (`paths: hubitat/**`) linked at `.agents/rules/hubitat.md`: the source-vs-bundle rule, the naming contract (bare lowercase library names with no `lib` suffix, kebab-case only when a name needs two words, kebab-case driver directories; camelCase Groovy because lifecycle, capability, and `customParse*Cluster` names are contracts), the fork provenance and how to diff against upstream, and the list of what was stripped so nothing re-adds it by reflex.
- No `hubitat/vendor/` directory.
  `hubitat/drivers/inovelli-dimmer-blue-series-VZM31-SN.groovy` stays until the VZM31-SN change replaces it; the two Home Assistant bridge files are not kkossev code and are untouched.

## Capabilities

### New Capabilities

- `hubitat-drivers`: the contract for Hubitat code in this repo — where libraries and drivers live and how they are named, that every Hubitat library and driver is in namespace `rbn`, that a driver's importable artifact is a generated bundle that is never hand-edited, the bundle's marker format, that forked files retain upstream attribution, and that the shared parse path contains no Tuya pre-processing.

### Modified Capabilities

- `repo-layout`: "Tool trees live at the repository root" gains `hubitat/` as a root tool tree, and "Root justfile modules resolve" gains the `hubitat` module.

## Impact

- **Hub-side**: eight `rbn` libraries and one `rbn` driver are added under Libraries Code and Drivers Code.
  No device changes driver.
  The VZM31-SN switches keep running Inovelli's driver; any `kkossev.*` code already on the hub is left in place.
  When a Cube does pair it will offer the `rbn` driver by fingerprint; that switch-over, and the runtime checks that go with it, belong to the follow-up change.
- **Validation ceiling**: this change proves the fork compiles (Hubitat compiles a whole bundle on save) and that the Tuya surface is gone from the source.
  It does not prove the parse path behaves on a live device.
  The follow-up runtime-validation change covers that, on whichever device is first available (a minimal standard-cluster VZM31-SN driver, or the Cube once paired).
- **Naming**: every library name in this change is a single lowercase word, so nothing here depends on Hubitat accepting a dash in a library `name`.
  Its documentation says dashes are allowed; that is verified on the hub the first time a two-word library (for example a future `device-profile`) is created, not now.
- **Upstream tracking**: the fork pins `0bf47407`; pulling an upstream fix becomes a manual diff of `Libraries/<lib>.groovy` between the pinned sha and upstream HEAD, applied by hand to `hubitat/libraries/<lib>.groovy`.
  The Tuya strip widens that diff permanently in `common`; the other seven stay close to verbatim.
- **Public repo**: `jmuchovej/homelab` is public, so `importUrl` can point at `raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/...` and the hub imports without HPM.
  Bundles are therefore committed artifacts, not build outputs.
- **Tooling**: one stdlib-only Python script under `hubitat/`, run through `uv run` from the `just` module; no new dependency in `pyproject.toml`, no `homelab` CLI wiring.
  Groovy is not formatted by `treefmt` (nothing in the repo configures a Groovy formatter), so the pre-commit `treefmt` hook is a no-op on these files.
- **Not touched**: `deviceProfileLibV4`, `groupsLib`, the VZM31-SN driver, the Home Assistant bridge app and driver, the kkossev libraries installed on the hub.
