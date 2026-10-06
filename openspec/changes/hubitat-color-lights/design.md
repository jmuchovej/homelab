## Context

See proposal.md for motivation.
Facts that shape the approach, read from the forked libraries, the upstream checkout at `0bf47407`, and the hub (read-only):

- **How `common` handles `0x0300` today.**
  `ClustersMap` has `/*0x0300: 'ColorControl',*/` commented out, and two patches compensate: a `case 0x0300` in `parse()` that calls `standardParseColorControlCluster(descMap, description)` through `respondsTo` and repeats it for each entry in `descMap.additionalAttrs`, and a `descMap.cluster != '0300'` clause in `standardAndCustomParseCluster()` that mutes the missing-handler warning.
  The dispatcher's own contract is one argument, `(descMap)`, and it already splits a multi-attribute read response into one call per attribute via `additionalAttrs`.
- **Why upstream patched it.**
  `ctLib`'s parser predates that split: it re-parses the raw `read attr - raw` string (`parseAttributeList`, `parseHex4le`) to find every attribute in one frame, which is why it needs the second argument.
  Its colour model is Ivar Holand's IKEA driver: XY only (`0x0003`/`0x0004`, accumulated in `state.colorX/Y`, converted XY → RGB → HSV), attribute `0x0007` left as a `TODO`, and **colour temperature imitated** by sending an XY colour at `WHITE_HUE` 8 with a saturation derived from kelvin.
  `setColor` queues commands on `state.cmds` and schedules `sendZigbeeCommandsDelayed` 100 ms later; `level`'s `setLevelBulb` queues on the same `state.cmds` under its own scheduled name, so a `setColor` carrying a level still leaves as one dispatch whichever timer fires first.
  `ctLib` also carries commented-out `startLevelChange`/`stopLevelChange` and live varargs `min`/`max`; it has no slashy strings, regex literals, or triple-quoted strings (`rg '=~|~/|"""'` is empty for both files).
- **`rgbLib`** is 126 lines of hooks (`updatedRGB`, `colorControlRefresh`, `colorControlConfig`, `refreshRGB`, `configureRGB`, `initializeRGB`, `initVarsRGB`, `initEventsBulb`, `testT`) with the capabilities declaration.
  `refreshRGB` reads Aqara `0xFCC0` attributes with `mfgCode 0x115F`, and `configureRGB` calls a `refreshBulb()` that none of the three upstream files defines.
- **The device.**
  Both strips are `TS0505B` / `_TZB210_tmi0rihb`, application 41, endpoint `01`; the hub's data map records no cluster list, and the manufacturer code is absent from upstream's fingerprint list.
  The built-in driver's state on device 36 shows the device is hue/saturation-native (`hexColor.currentHue`/`currentSaturation`, `xyOnly: false`), a colour-temperature range of 2000–6535 K, and `groups: ["2700"]` — little-endian `0x0027` = 39, which is the `Group_39` DNI of group device 52 (Groups-app child 39).
  Device 36 is a member of that group; device 35 is not; the group device's type is `Group Dimmer`.
  Device 36 last spoke 2026-09-30, device 35 2026-06-02 (unmounted for a period, reconnected 2026-10-05), yet on 2026-10-06 both are in the hub's neighbour table (LQI 196 and 187, age 3): powered, joined, routing, and silent.
  Device 35 has no current states at all, so the built-in driver never polled it successfully either.
- **Upstream's TS0505B driver** (`Tuya Advanced Zigbee RGBW Bulb`, standalone, not on the libraries) is the reference for the Tuya knobs only: power restore = `0x0006:0x4003` ENUM8 plus `0x0300:0x4010` UINT16 `0xFFFF`; do-not-disturb = `zigbee.command(0x0300, 0xFA, …, '00' | '01')`.
  Its reporting block is Philips-Hue residue and is **not** a template: it enables reporting for hue and saturation only, and sets on/off, level, XY, and colour-temperature reporting to a `0xFFFF` maximum, i.e. off.
  It also declares an `endpointId F2 … model unknown manufacturer unknown` trap fingerprint.
- **What `level` and `switch` do with `DEVICE_TYPE`.**
  `setLevel` always goes through `setLevelBulb` (the `DEVICE_TYPE in ['Bulb']` guard is commented out upstream); `level`'s transition preferences render when `DEVICE_TYPE != 'Device'`, `switch`'s advanced options when not `Device` or `Thermostat`.
  Upstream's only library-based colour driver (Aqara LED Strip T1) uses `'Bulb'`.
- **No library parses the Groups cluster.**
  `0x0004: 'Groups'` is in the registry, but nothing defines `standardParseGroupsCluster`, so a Get Group Membership response would log as a missing handler.
- The VZM31-SN precedents that carry over unchanged: `customRefresh` as the whole refresh list, `customConfigureDevice` as the whole configure list, device-is-truth preferences with `device.updateSetting` needing one Save Preferences first, `probe`/`push` as the compile checks.

## Goals / Non-Goals

**Goals:**

- A colour library that drives an RGB+CCT device the way the device works: real colour-temperature mode, hue/saturation that round-trip, state that stays current through reporting.
- `common`'s dispatch path with no cluster-specific exception left in it.
- Both strips validated end to end, 36 first; 35, with no stored state, is the cleaner proof that reporting works.

**Non-Goals:**

- Colour effects, scenes, Touchlink, the `enhancedHue` attributes, or a reporting-vs-polling preference.
- A Groups-cluster parser or a membership read in the driver (see D11; an open question).
- Any `0xEF00` handling.
- Porting the upstream TS0505B driver or any of its fingerprints for other manufacturers.
- Changing `level`'s or `switch`'s behaviour; the colour library adapts to them.

## Decisions

### D1. One library, `color`, forked from both `ctLib` and `rgbLib`

`rgbLib` is a capability declaration plus eight hooks that only make sense next to `ctLib`'s parser and maths, and no upstream driver includes one without the other.
One file means one include line per colour driver, one provenance block (naming both upstream paths), and one attribution row.
Rejected: two libraries (`color` + `rgb`) mirroring upstream — doubles the ceremony for 126 lines and invites the "which one do I include" question; the upstream split exists because the files were written a year apart, not because they separate concerns.

### D2. `0x0300` joins the registry; both patches go; the parser takes `(descMap)`

`ClustersMap` gets `0x0300: 'ColorControl'`, the `case 0x0300` in `parse()` is deleted, and the `!= '0300'` clause in the missing-handler warning is deleted.
The library's `standardParseColorControlCluster(final Map descMap)` handles one attribute per call, which is exactly what the dispatcher delivers once it has split `additionalAttrs`; `parseAttributeList`/`parseHex4le`/the raw-string path are dropped, since the hub's `parseDescriptionAsMap` has already done that work.
XY still needs both halves before a conversion, so the `state.colorXReported`/`colorYReported`/`colorChanged` accumulation stays, triggered per attribute instead of per frame.
`common`'s provenance line gains "`0x0300` ColorControl routed through `ClustersMap`; the two `0x0300` patches removed".
Rejected: keeping the patch (the rules say the map is the registry, and the second patch silences the missing-handler warning for every driver on the hub, colour or not); routing `0x0300` through `customParse*` in the driver (would put the colour parser in every colour driver).

### D3. Colour temperature is a real Zigbee operation

`setColorTemperature(kelvin, level, rate)` sends Move to Color Temperature (`0x0300` command `0x0A`) with mireds (`1e6 / kelvin`, little-endian) and a transition time, clamped to the device's `0x400B`/`0x400C` range read on `configure` and kept in `state.ct` (fallback 153–500 mireds when unread).
The command is built with `zigbee.command(0x0300, 0x0A, …)` and a hand-packed payload; no `zigbee.setColorTemperature`-style helper is assumed to exist until seen compiling on the hub.
Attribute `0x0007` becomes `colorTemperature` (kelvin) and `colorMode` `CT`; attribute `0x0008` becomes `colorMode` (`0`/`1` → `RGB`, `2` → `CT`); the `WHITE_HUE`/`MAX_WHITE_SATURATION` inference and the "CT if hue is 8" branch in `updateColor` are deleted.
Rationale: an RGB+CCT strip lights its white LEDs only in colour-temperature mode; upstream's imitation keeps it in colour mode with a tinted RGB white, which is wrong output and reports `colorMode CT` for something that is not.
Rejected: forking as-is and fixing later — would ship a strip whose "white" is RGB, and the validation scenario would fail on day one.

### D4. `setColor` sends hue and saturation; XY is parsed, not sent

`setColor` sends Move to Hue and Saturation (`0x0300` command `0x06`) with hue and saturation scaled 0–100 → 0–254, plus a `setLevel` through `level` when a level is given, keeping upstream's `state.cmds` queue and 100 ms coalescing so colour and level leave together.
`setHue`/`setSaturation` compose with the current other half as upstream does.
Reports of `0x0000`/`0x0001` map straight back to `hue`/`saturation` (0–254 → 0–100); reports of `0x0003`/`0x0004` go through the retained XY → RGB → HSV maths for devices that report XY; `color` (hex) is derived with Hubitat's `ColorUtils` either way.
Rationale: the device is hue/saturation-native (its built-in driver stores and sends exactly that), so the values the hub reports are the values the user set, which removes the XY round-trip drift between what was set and what reads back.
Rejected: keeping upstream's XY send path — works, but `hue 33` would read back as 32 or 34 after two lossy conversions, and the spec scenario comparing set and reported hue is the point.

### D5. Named deletions from the fork

Dropped and listed in the `Modified for the rbn namespace:` line: `startLevelChange`/`stopLevelChange` (commented out upstream, but a reflex to re-enable; `level` owns `ChangeLevel`), varargs `min`/`max` (shadow Groovy's `Math` and `Collection` versions and only exist to feed the colour maths, which uses `Math.min`/`Math.max` after the fork), `testT`, the `0xFCC0` Aqara reads in `refreshRGB` (device glue; the Aqara T1 driver, if ever ported, adds them in its own `customRefresh`), the `refreshBulb()` call in `configureRGB` (undefined), and `parseAttributeList`/`parseHex4le` (D2).
Kept: the gamma and XY/RGB/HSV maths, the 500 ms delayed-event helpers (they coalesce the burst of events a single colour change produces), `setGenericTempName`/`setGenericName`, `initVarsRGB`/`initEventsBulb`.

### D6. Driver identity: directory `btf-lm052`, name `BTF LED Strip Controller (LM052)`, no trap fingerprint

The directory parallels `inovelli-vzm31-sn` — vendor's short name plus model, kebab-case — and the untracked stub directory `btf-lighting-lm052` is removed rather than renamed, since nothing tracks it.
The display name leads with what a person sees in the Type dropdown (a BTF strip controller) and keeps the model for fingerprint matching; `deviceJoinName` is `BTF LED Strip Controller`.
One fingerprint: `profileId 0104, endpointId 01, model TS0505B, manufacturer _TZB210_tmi0rihb`, with `inClusters`/`outClusters` from the hub's device details if the page shows them and otherwise upstream's generic TS0505B list (`0003,0004,0005,0006,1000,0008,0300,EF00,0000` / `0019,000A`), since Hubitat matches on model and manufacturer.
Upstream's `endpointId F2` trap fingerprint is **not** copied: it claims every device the F2 bug mangles, which is a support measure for a public driver, not for two strips whose records already show endpoint `01`.
Rejected: `btf-lighting-lm052` (the brand's full name, but not what anyone types, and it breaks the vendor-model pattern); adding other manufacturers' TS0505B fingerprints (unverified hardware).

### D7. `DEVICE_TYPE 'Bulb'`; preferences come from the libraries plus two of the driver's own

`'Bulb'` matches `deviceType`, the upstream colour driver, and the preference gates in `switch` and `level`.
`level`'s transition preferences (`levelUpTransition`, `levelDownTransition`, `levelChangeRate`) render as upstream renders them; whether `setLevelBulb` honours them is upstream's business and not changed here.
The driver adds `powerRestore` (`0x00` off, `0x01` on, `0xFF` last state) and `doNotDisturb` (`0`/`1`) as enums, both without a `defaultValue` so a blank preference means "never set" (D8).
No `enableReporting` toggle: reporting is what `configure` does; if the device turns out not to honour it, that is a finding to record (Risks), not a preference to pre-empt.

### D8. Device is the source of truth for the two knobs; `configure` writes neither

`customRefresh` includes a read of `0x0006:0x4003`; the parser (a `customParseOnOffCluster` that handles `attrId 4003` and delegates everything else to `standardParseOnOffCluster`) sets `settings.powerRestore` via `device.updateSetting` and `state.powerRestore`.
`customUpdated` writes `0x4003` and `0x0300:0x4010 = 0xFFFF` only when `settings.powerRestore` differs from `state.powerRestore`, then reads `0x4003` back; it sends `0x0300` command `0xFA` only when `settings.doNotDisturb` differs from `state.doNotDisturb`, then records the sent value and time in state — the command has no read-back, so state is the best record there is and the README says so.
`customConfigureDevice` returns reporting configuration and the one-time capability/range reads (D9) and nothing else.
Rationale: the VZM31-SN pattern; a strip configured by hand once is never reset by a click, and a blank preference is never written.
`device.updateSetting` needs the settings row to exist, so the README's "Save Preferences once, then refresh" step applies to this driver too.
Rejected: writing both on every save (upstream's `configure` does, and it also runs on install) and applying defaults on `configure`.

### D9. Reporting is configured in `customConfigureDevice`, one dispatch, for the attributes the parser handles

`0x0006:0x0000` BOOLEAN (min 0, max 300), `0x0008:0x0000` UINT8 (1, 300, delta 1), and `0x0300` `0x0000` UINT8, `0x0001` UINT8, `0x0003` UINT16, `0x0004` UINT16, `0x0007` UINT16, `0x0008` ENUM8 (1, 300, delta 1 where applicable), followed by reads of `0x0300:0x400A` (colour capabilities) and `0x400B`/`0x400C` (colour-temperature range, into `state.ct`).
XY is included although D4 does not send it, because a group command or another controller may put the device in XY mode and the hub should still learn the result.
The 300 s maximum is the keep-alive that stops the hub marking a powered strip `INACTIVE`.
Rationale: the built-in driver's symptom is state that never changes until polled; reporting on exactly the attributes the parser turns into events is the smallest fix.
Rejected: upstream's block (Hue residue; disables most of this), and `rgbLib`'s `colorControlConfig` (XY only).

### D10. `customRefresh` is one dispatch

`zigbee.onOffRefresh()` + `zigbee.levelRefresh()` + one multi-attribute read of `0x0300` `[0x0000, 0x0001, 0x0003, 0x0004, 0x0007, 0x0008]` + `readAttribute(0x0006, 0x4003)`, returned as one list; `common.refresh()` sends it once and the dispatcher fans the multi-attribute response out per attribute (D2).
`refreshRGB`'s `state` resets (`colorChanged`, `colorXReported`, `colorYReported`, `cmds`) are kept so a refresh starts a clean XY accumulation.

### D11. Group membership is proven functionally, not read by the driver

With no Groups-cluster parser in the libraries, a membership read would need a new `customParseGroupsCluster` in the driver and a `groups` attribute — a scope the proposal does not ask for.
The fingerprint carries `0004` in `inClusters`, and the proof is: after the driver swap, set the group device's level and watch the strip follow and report (D9).
If it does not follow, the README's recovery (toggle "Use Zigbee group messaging" off and on with a save) is applied; if it still does not, that is recorded as a finding and becomes a design question for the next change, not a silent fallback.
How the Groups app decides a driver "speaks groups" is undocumented; this change does not pretend to know.

### D12. Version `0.1.0` is the release; no ceremonial bump

The driver is written at `0.1.0`, pushed with `just hubitat push` during development, validated, and released at `0.1.0` once any defects found in validation are fixed; HPM adopts the pushed driver through Match Up (or the manifest URL is installed directly — both paths were proven in `hubitat-runtime-validation`).
Manifest: `packageName` = display name, `category` `Control`, tags `Zigbee`, `Lights & Switches`, fresh `uuidgen` ids for the manifest and the index entry, `minimumHEVersion` `2.3.6.0`.
Rejected: a `0.1.1` bump after validation as in the VZM31-SN precedent — that bump was the HPM update-detection test, which does not need repeating.

### D13. Commits land per task group

`feat(hubitat): route 0x0300 through the cluster registry` (`common` plus the regenerated Cube and VZM31-SN bundles, which inline it), `feat(hubitat): color library and BTF LM052 driver` (library, driver, its bundle, manifest, index), `docs(hubitat): colour library and LM052` (README, AGENTS), and `chore(openspec): record hubitat-color-lights results`; hub-only groups produce no commit.
Each commit is by explicit fileset, since the sibling change is editing `common`, README, and AGENTS in the same workspace.

## Risks / Trade-offs

- [The device ignores Configure Reporting (Tuya firmware quirk)] → Validation watches for an unsolicited report after an HA-side change; if none arrives in 300 s, it is recorded against the device and a polling fallback becomes an open question — not added speculatively.
- [The device reports in XY after a group command and the hub's hue/saturation come from the lossy conversion] → Accepted: XY reports are converted and the deviation is rounding-sized; hub-initiated colour stays HS (D4).
- [Colour-temperature range differs from the built-in driver's 2000–6535 K] → Read from `0x400B`/`0x400C` on `configure`, clamped; fallback range is the ZCL common one.
- [A `zigbee.*` helper assumed by the fork does not exist on Hubitat] → Commands are built with `zigbee.command`/`readAttribute`/`writeAttribute`/`configureReporting` only, all already used by the forked libraries; `probe` and `push` catch anything else before a device is touched.
- [`state.cmds` shared between `level` and `color`] → Deliberate upstream batching; the fork keeps both scheduled-method names so a `setColor` with level still leaves as one dispatch.
- [Removing the `0x0300` patches changes `common` for every driver] → All bundles are regenerated and the Cube and VZM31-SN drivers re-pushed; neither device sends `0x0300`, so the only visible change is that a stray `0x0300` frame would now warn "missing handler" instead of being swallowed.
- [The Groups app does not re-join the strip after the driver swap] → D11's recovery, then a recorded finding.
- [Device 35 answers nothing even after `configure`] → It is a neighbour with good LQI, so silence after reporting is configured is a device finding (recorded, with the raw configure-reporting responses), not a mesh problem; the orphan recipe in `hubitat/AGENTS.md` applies only if it ever leaves the neighbour table.
- [`_TZB210_tmi0rihb`'s cluster list cannot be learned] → The fingerprint still matches on model and manufacturer; the generic list is used and the gap noted in the driver header.
- [Hue/saturation scaling off by one between 0–100 and 0–254] → The round-trip scenario tolerates ±1 and the conversion is the one Hubitat's built-in drivers use (`× 254 / 100`, rounded).
- [DND has no read-back] → State records what was sent; the README states that the preference shows the last value this driver sent, not what the device holds.
- [The sibling change lands first and moves the `ClustersMap` line] → Both edits are single entries in one map literal; the rebase is re-adding one entry and re-bundling.

## Migration Plan

1. Repo: `common` (map entry, two patch removals, provenance), `color` library, driver, manifest, index; `just hubitat bundle`, `check`, `probe`; `push` all three drivers; commits for the first two groups.
2. Hub, both strips: confirm each is still in `/hub/zigbee/getChildAndRouteInfo`'s neighbour table (both were on 2026-10-06) and record the LQI.
3. Hub, device 36: record the built-in driver's settings; select ours; Save Preferences once untouched; `refresh`; `configure`; operate from the page (on/off, level, colour, colour temperature); set it from Home Assistant and from the group device and watch reports; power-cycle it and watch power restore; set DND and power restore through preferences; record log excerpts.
   Rollback at any point: reselect `Advanced Zigbee RGBW Bulb`; the configured reporting persists on the device and is harmless to the built-in driver.
4. Hub, device 35: the same, with the extra check that its first `refresh` populates every attribute from nothing.
5. Repo: README (status row, attribution row, a short LM052 section), AGENTS, release commit at `0.1.0`; the user pushes; HPM Match Up adopts the driver.
6. Repo: the openspec record commit.

## Open Questions

- Whether a `customParseGroupsCluster` and a `groups` attribute belong in the driver so membership is a fact on the page as `bindings` is for the VZM31-SN.
  Deferrable; D11's functional proof covers this change.
- Whether the VZM31-SN at device 49's stale endpoint-2 binding to group `0x2700` (noted in the unit rollout) was an attempt to drive these strips — the built-in driver stores group 39 as the little-endian string `2700`, which is a plausible source of the mistake.
  If so, `bindGroup 39` on that switch after this change makes the strips a unit; out of scope here.
- Whether `level`'s transition preferences should be hidden for `'Bulb'` devices, since `setLevelBulb` does not read them.
  Deferrable and upstream's.
- A polling fallback if the device does not honour reporting (see Risks).
