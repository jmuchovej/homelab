## Why

`hubitat-rbn-libraries` proved that the forked `rbn` libraries compile and that the Tuya surface is gone from the source.
It proved nothing about behaviour on a device, because nothing was available to run them on: the Aqara Cube T1 Pro fails Hubitat's join step before any driver is selected, and the Inovelli VZM31-SN dimmers that are paired have no `rbn` driver.
The strip touched the hot path of every message (`parse()`), the batching that is the whole point of the fork (`sendZigbeeCommands()`), and the on/off and battery handlers; a regression there is invisible until something runs.
A deliberately minimal VZM31-SN driver — standard clusters only, none of Inovelli's private `0xFC31` surface — is the smallest thing that puts six of the eight libraries on hardware the user owns today, and it is not throwaway: it is the seed the full driver extends in place.
The same change packages the tree for the Hubitat Package Manager, because HPM's only driver input is the single-file bundle the previous change already generates, so adding a manifest per driver and one index is a few JSON files plus a drift guard, and doing it now means the full VZM31-SN driver later arrives as an HPM _update_ rather than a new install.

## What Changes

- Add `hubitat/drivers/inovelli-vzm31-sn/` with a minimal driver `Inovelli Dimmer (Blue, VZM31-SN)` (namespace `rbn`; the display name leads with what the device is, since the model code is not what anyone remembers) including `rbn.common`, `rbn.switch`, `rbn.level`, `rbn.meter`, `rbn.reporting`.
  It declares the upstream fingerprints, `DEVICE_TYPE 'Dimmer'`, a `customRefresh()` that reads on/off, level, energy, and active power in one command list, and two overrides for the device's metering scale (`0x0702:0x0000` is hundredths of a kWh, `0x0B04:0x050B` is tenths of a watt; `meter`'s standard parsers assume ÷10 and ÷1).
  No `0xFC31` handling, no parameters, no LED or scene surface.
  Its bundle is generated and committed like the Cube's.
- Run the runtime validation on **one** dimmer: switch it to the `rbn` driver, exercise refresh, on/off/dim from the hub and at the wall, observe power and energy reports, confirm `0xFC31` traffic is logged as an unknown cluster and nothing else, then switch it back to Inovelli's driver.
  Configure is **not** pressed during the test so `reporting` never rewrites the attribute-reporting configuration Inovelli's driver set.
- Gate the Cube's runtime scenarios (gestures, battery) on a Cube pairing; they are tasks in this change that may be marked blocked at archive time without failing it.
  Pairing guidance (keep the device awake through Hubitat's initialising step) is recorded, but pairing itself is not something a driver can fix.
- Add HPM packaging: `packageManifest.json` beside each driver source, whose single `drivers[]` entry points `location` at the committed bundle's raw URL on `main`; `hubitat/repository.json` listing every manifest so the tree can be added once as an HPM custom repository.
  Package ids are UUIDs minted once and never changed.
- Extend `just hubitat check` (the bundler's `--check`) to refuse: a manifest whose `version` differs from the driver's `version()`, a manifest whose driver `name`/`namespace` differ from the driver's `definition`, a manifest `location` that does not resolve to the bundle beside it, and a `repository.json` entry whose manifest file does not exist.
  HPM's update detection is the manifest `version` string alone, so drift here means users silently never see updates.
- Document both HPM entry points in `hubitat/README.md` (Install → From a URL with a manifest URL; Settings → Add a custom repository with the index URL) and update the validation-status section from "compile-verified only" to what was actually observed on hardware, per library.
- Update `hubitat/AGENTS.md` with the manifest rules (version bump = manifest bump, ids are permanent, HPM never installs libraries so the bundle is the artifact).

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `hubitat-drivers`: gains requirements for HPM packaging (per-driver manifest, repository index, drift refusal), for the minimal VZM31-SN driver's observable behaviour on standard clusters including its metering scale, and for the README recording which libraries have been runtime-verified and on what.
  The capability is introduced by the in-flight `hubitat-rbn-libraries` change; this delta adds requirements only and modifies none of that change's, so it is independent of archive order.

## Impact

- **Hub-side, one Inovelli dimmer, for the duration of the test**: loses scene/multi-tap button events, LED notifications, and the parameter UI (all `0xFC31`).
  On/off, dimming, and power/energy keep working.
  Parameters live on the device, so nothing is lost; rollback is reselecting Inovelli's driver.
  The other dimmers are untouched.
- **Hub-side, Cube**: unchanged unless one pairs.
  If it does, it is offered the `rbn` driver by fingerprint and the gated tasks run.
- **Hub-side, HPM**: the Cube driver saved by hand in the previous change must be adopted through HPM's Match Up before the custom repository is added, or HPM will offer to install a duplicate.
  The VZM31-SN driver is installed through HPM from the start, which is also the test of that path.
- **Sequencing**: assumes `hubitat-rbn-libraries` is applied (its hub tasks 6.1–6.3 done, bundles committed and pushed) — HPM needs the raw URLs live, and the libraries must already compile.
  It does not need that change archived.
- **Repo**: three new JSON files, one new driver directory, `bundle.py` grows a manifest check, README and AGENTS updates.
  No Nix, no CI.
- **Reporting configuration**: the Inovelli driver's user-set reporting intervals are not touched by this change.
  The minimal driver's `configure()` path is left as the libraries' default and is simply never invoked during validation; a future full driver decides what reporting it owns.
- **Not touched**: `0xFC31` support, `ClustersMap`, the deferred `deviceProfileLib` decision, the `switch`/`level` merge question, the hub's `kkossev.*` entries.
