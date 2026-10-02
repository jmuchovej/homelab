## 1. Preconditions

- [ ] 1.1 Confirm `hubitat-rbn-libraries` is applied on the hub: Libraries Code lists eight `rbn` entries and Drivers Code lists `Aqara Cube T1 Pro` in namespace `rbn` (its tasks 6.1–6.3).
  If not, stop; this change depends on them
- [ ] 1.2 Confirm the previous change is pushed and the raw URL is live: `curl -sS -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/drivers/aqara-cube-t1-pro/aqara-cube-t1-pro.bundled.groovy` prints `200`
- [ ] 1.3 (hub, by hand) Pick the one dimmer for validation and record in a scratch note: its device name, current driver (`Inovelli Dimmer 2-in-1 Blue Series VZM31-SN`), firmware, and the power/energy reporting parameters shown on its page, so 5.9 can confirm nothing changed

## 2. Minimal VZM31-SN driver

- [ ] 2.1 Write `hubitat/drivers/inovelli-vzm31-sn/inovelli-vzm31-sn.groovy` per design D1–D3: standard header with `version()` `0.1.0` and a `timeStamp()`; `_DEBUG = false`; imports; `deviceType = 'Dimmer'` and `DEVICE_TYPE`; `#include rbn.common`, `rbn.switch`, `rbn.level`, `rbn.meter`, `rbn.reporting`; `metadata { definition(name: 'Inovelli Dimmer (Blue, VZM31-SN)', namespace: 'rbn', author: 'John Muchovej', importUrl: <raw bundle URL>, singleThreaded: true) { capability 'Sensor' } }` with the two upstream fingerprints copied verbatim (EP01 and EP02, model `VZM31-SN`, manufacturer `Inovelli`) plus `deviceJoinName: "Inovelli Dimmer (Blue)"` on each and the standard `txtEnable`/`logEnable` preferences; `customRefresh()` returning `zigbee.onOffRefresh() + zigbee.levelRefresh() + zigbee.readAttribute(0x0702, 0x0000) + zigbee.readAttribute(0x0B04, 0x050B)`; `customParseMeteringCluster(Map)` handling `attrId == '0000'` as `hexStrToUnsignedInt(value) / 100` → `sendEnergyEvent`, else delegating to `standardParseMeteringCluster`; `customParseElectricalMeasureCluster(Map)` handling `attrId == '050B'` as `/ 10` → `sendPowerEvent`, else delegating to `standardParseElectricalMeasureCluster`; no `customConfigureDevice`, no `0xFC31` code.
  A header comment states the driver is the standard-cluster seed of the full driver and that `voltage`/`amperage` capabilities come from `meter` and are not reported by this device.
  Verify `rg -n 'FC31|setParameter|ledEffect' <file>` is empty and the file is under 150 lines
- [ ] 2.2 `just hubitat bundle hubitat/drivers/inovelli-vzm31-sn/inovelli-vzm31-sn.groovy` (the `hubitat` Python module from `hubitat-cli`; `uv run --package hubitat -m hubitat bundle …` is the same thing) and track the bundle.
  Verify `just hubitat check` exits 0, `rg -c 'start include rbn\.' <bundle>` prints `5`, and the bundle's first N lines differ from the source only at the five include lines

## 3. HPM packaging and the drift guard

- [ ] 3.1 The manifest models and checks already exist from `hubitat-cli` (`hubitat/manifest.py`: `check_manifest(source, required=…)`, `check_repository()`, covered by `hubitat/tests/test_manifest.py`) and `check` runs them for every driver that has a manifest.
  What remains per design D5 is to make a manifest mandatory: pass `required=True` from `check` in `hubitat/cli.py`, add the `category`/`tags` non-empty assertion to `check_repository()` with a test, and confirm `just hubitat check` now exits 1 naming the two missing manifests; then proceed to 3.2
- [ ] 3.2 Write `hubitat/drivers/aqara-cube-t1-pro/packageManifest.json` (D7): `packageName` `Aqara Cube T1 Pro`, `author`, `version` `3.3.0`, `minimumHEVersion` `2.3.6.0`, `dateReleased`, `releaseNotes`, `documentationLink`, `drivers[]` with `id` from `uuidgen`, `name` `Aqara Cube T1 Pro`, `namespace` `rbn`, `location` the raw bundle URL, `required: true`.
  Verify `just hubitat check` exits 0 and `yq -p json '.drivers[0].id' <file>` prints a UUID
- [ ] 3.3 Write `hubitat/drivers/inovelli-vzm31-sn/packageManifest.json` the same way with `packageName` `Inovelli Dimmer (Blue, VZM31-SN)`, `version` `0.1.0`, `releaseNotes` stating standard clusters only and that `0xFC31` features are not yet implemented.
  Verify `just hubitat check` exits 0
- [ ] 3.4 Write `hubitat/repository.json`: `author`, `gitHubUrl` `https://github.com/jmuchovej/homelab`, `payPalUrl` `null`, `packages[]` with one entry per manifest: fresh `uuidgen` `id`, `name`, `category` `Control`, `location` the manifest's raw URL, a one-line `description`, `tags` `["Zigbee","Buttons"]` for the Cube and `["Zigbee","Lights & Switches","Energy Monitoring"]` for the dimmer.
  Verify `just hubitat check` exits 0 and `yq -p json '.packages | length' hubitat/repository.json` prints `2`
- [ ] 3.5 Prove the guard end to end (`just hubitat check` is the module's `check` command): change the Cube manifest `version` to `3.3.1`, verify `just hubitat check` exits 1 naming it, revert; remove the dimmer entry from `repository.json`, verify exit 1 naming the missing manifest, revert; verify exit 0

## 4. Documentation

- [ ] 4.1 `hubitat/README.md`: add an **Installing with HPM** section with both entry points (Install → From a URL with a manifest URL; Settings → Add a custom repository with `https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/repository.json`), the Match Up note for code saved by hand, and the rule that a release is a `version()` + manifest bump; replace the validation paragraph with the per-library status matrix from design D8, initially all `compile-verified`.
  Verify the matrix has eight rows
- [ ] 4.2 `hubitat/AGENTS.md`: add the manifest rules (every driver has a `packageManifest.json`; `version` must match `version()` and `check` enforces it; ids are permanent; HPM installs the bundle, never libraries; `repository.json` lists every manifest).
  Verify the section exists and names `just hubitat check`
- [ ] 4.3 Commit groups 2–4 as three commits (`feat(hubitat): add minimal Inovelli Blue dimmer (VZM31-SN) driver`, `feat(hubitat): HPM manifests, repository index, manifest drift check`, `docs(hubitat): HPM install and validation status`) with explicit filesets; verify `jj diff -r @- --stat` for each lists only its files.
  Push is the user's

## 5. Hub runtime validation on one dimmer (by hand, Live Logs open, debug logging on)

- [ ] 5.1 HPM → Package Manager Settings → Match Up; verify it adopts `Aqara Cube T1 Pro` (namespace `rbn`) and lists it as managed
- [ ] 5.2 HPM → Install → From a URL with `https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/drivers/inovelli-vzm31-sn/packageManifest.json`; verify it completes and Drivers Code shows `Inovelli Dimmer (Blue, VZM31-SN)` in namespace `rbn`.
  This is the HPM path under test, so it stays an HPM install even though the driver can be pushed directly: if it was already pushed with `just hubitat push` during 2.x, run Match Up first so HPM adopts it instead of offering a duplicate, and verify afterwards that `just hubitat push --dry-run` reports it `unchanged`
- [ ] 5.3 HPM → Settings → Add a custom repository with the `repository.json` URL; verify Install → From a Repository lists both packages, each rendered as `<name> by John Muchovej`
- [ ] 5.4 On the chosen dimmer's page select driver `Inovelli Dimmer (Blue, VZM31-SN)` (namespace `rbn`), Save Device.
  Do **not** press Configure.
  Verify the log shows `checkDriverVersion` updating to `0.1.0` and no `error` lines
- [ ] 5.5 Press `refresh`.
  Verify exactly one `sendZigbeeCommands: sent cmd=` line whose list contains reads of `0x0006`, `0x0008`, `0x0702:0x0000`, and `0x0B04:0x050B`, followed by `switch`, `level`, `energy`, and `power` events
- [ ] 5.6 From the page: `off`, `on`, `setLevel 40`, `setLevel 100`.
  Verify the load follows and `switch`/`level` events match.
  At the wall: paddle down, paddle up, hold up to dim.
  Verify `switch`/`level` events with `type: physical`
- [ ] 5.7 Compare one `power` and one `energy` event against the raw hex in the same log line.
  Verify power = raw ÷ 10 W and energy = raw ÷ 100 kWh (spec scenario values: raw 150 → 15.0 W, raw 2600 → 26.00 kWh)
- [ ] 5.8 Double-tap the paddle once.
  Verify an unknown-cluster warning naming `0xFC31`, no `error`, no button event.
  Verify the whole session's log has no line containing `Tuya`
- [ ] 5.9 Reselect driver `Inovelli Dimmer 2-in-1 Blue Series VZM31-SN`, Save Device, do **not** Save Preferences.
  Verify scene buttons and LED behave as before, and the reporting parameters on the page match the 1.3 note
- [ ] 5.10 Record all findings (log excerpts, any deviation) in a scratch note for 6.x; if any of 5.4–5.8 failed, stop here and report the failure against the library it implicates

## 6. Record results and release

- [ ] 6.1 Update the README status matrix: `common`, `switch`, `level`, `meter`, `reporting` → `runtime-verified`, `VZM31-SN`, date; the other three unchanged.
  Verify eight rows, five flipped
- [ ] 6.2 If 5.x surfaced a library defect, fix it in `hubitat/libraries/`, re-bundle both drivers, verify `just hubitat check` exits 0, and record the fix in the affected library's provenance line and the Cube manifest's `releaseNotes` with a version bump; otherwise mark this task done with "no defects found"
- [ ] 6.3 Bump the dimmer driver: `just hubitat bump inovelli-vzm31-sn 0.1.1` (rewrites `version()`/`timeStamp()`, the manifest `version`/`dateReleased`, and re-bundles), then set the manifest `releaseNotes` to "runtime validated on hardware" by hand; verify `just hubitat check` exits 0
- [ ] 6.4 Commit as `feat(hubitat): VZM31-SN 0.1.1 — runtime validated` and `chore(openspec): record hubitat-runtime-validation results`; verify scoped diffs.
  Push is the user's
- [ ] 6.5 (hub, after push) HPM → Update; verify `Inovelli Dimmer (Blue, VZM31-SN)` is offered at 0.1.1 and updates cleanly

## 7. Cube runtime scenarios (gated on a Cube pairing)

- [ ] 7.1 Pair a Cube: keep pressing the link button (or keep shaking it) through Hubitat's initialising step.
  Verify the device appears with driver `Aqara Cube T1 Pro` in namespace `rbn` by fingerprint; if the join still fails, mark 7.x blocked with the symptom and continue to 7.5
- [ ] 7.2 Press Configure once (this driver's `customConfigureDevice` is the intended Aqara setup).
  Verify one `sendZigbeeCommands: sent cmd=` line and no `error`
- [ ] 7.3 Flip, shake, rotate left, rotate right.
  Verify `pushed`, `doubleTapped`, `held`, `released` with `cubeSide`/`angle`/`sideUp` updating
- [ ] 7.4 Wait for a battery report.
  Verify `battery` and `batteryVoltage` events and that `0xFCC0` reports parse without an unknown-cluster warning
- [ ] 7.5 Update the README matrix (`xiaomi`, `button`, `battery` → `runtime-verified`, `Cube`, date, or leave `compile-verified` with a note that pairing is pending); commit as `docs(hubitat): Cube runtime validation` if anything changed
