## Why

Two BTF Lighting LM052 RGB+CCT strip controllers (Tuya `TS0505B`, manufacturer `_TZB210_tmi0rihb`; hub devices 35 and 36) run on Hubitat's closed-source `Advanced Zigbee RGBW Bulb` driver, and the hub has lost track of both: 36 has been `INACTIVE` since 2026-09-30 and 35 since 2026-06-02 (it was unmounted for a while and reconnected on 2026-10-05).
Both are powered and joined — on 2026-10-06 the hub's neighbour table lists them at LQI 196 and 187 — yet neither has sent the hub a frame in weeks, and 35 has no stored state at all.
That is the known TS0505B habit of never reporting state unless reporting is configured, which the built-in driver does not do and which nothing we own can fix while the driver is a black box; the Tuya-side knobs that matter for a strip (power-restore behaviour, "do not disturb") are reachable only through whatever that driver chose to expose.
The `rbn` libraries have no colour library at all — `common` carries `0x0300` commented out of its `ClustersMap` and a hand-written patch in `parse()` that routes the cluster to a parser no library defines — so a colour device is the first thing the fork cannot drive today, and with `common`, `switch`, and `level` runtime-verified on the VZM31-SN there is finally a stable base to put colour on.

## What Changes

- Fork **one** colour library, `hubitat/libraries/color.groovy`, from upstream's `Libraries/ctLib.groovy` and `Libraries/rgbLib.groovy` at commit `0bf47407` (one provenance block naming both paths).
  Named deletions, listed in its `Modified for the rbn namespace:` line: the commented-out `startLevelChange`/`stopLevelChange` and the varargs `min`/`max` helpers from `ctLib` (the former would collide with `level`'s, the latter shadow Groovy's own), the Aqara `0xFCC0` reads inside `rgbLib`'s `refreshRGB` (device glue, not library), and `rgbLib`'s `testT`.
  Named changes: colour temperature becomes a real Zigbee operation — a Move to Color Temperature command and parsing of `0x0300:0x0007` (mireds) and `0x0008` (colour mode) — instead of upstream's white-hue-via-XY imitation, which would leave an RGB+CCT strip's white channels dark; hue and saturation attributes (`0x0000`/`0x0001`) are parsed alongside the XY pair.
- `common`: `0x0300: 'ColorControl'` is uncommented in `ClustersMap` and both `0x0300` patches are deleted — the `case 0x0300` in `parse()` and the `descMap.cluster != '0300'` exclusion that silences the missing-handler warning in the dispatcher — so colour dispatches through the registry like every other cluster; the colour library's parser takes the dispatcher's one-argument `(descMap)` signature and reads the multi-attribute split `common` already performs instead of re-parsing the raw description string.
  The provenance line in `common` grows one clause.
- A driver `hubitat/drivers/btf-lm052/btf-lm052.groovy`, `BTF LED Strip Controller (LM052)` in namespace `rbn`, `DEVICE_TYPE 'Bulb'`, built on `rbn.common`, `rbn.switch`, `rbn.level`, `rbn.color`, with a fingerprint for model `TS0505B` manufacturer `_TZB210_tmi0rihb`, version `0.1.0`.
  The untracked one-line stub at `hubitat/drivers/btf-lighting-lm052/` is removed in its favour.
- The driver owns the two Tuya-specific knobs as preferences written on Save Preferences only when changed, after the VZM31-SN's device-is-truth pattern: **power restore** through the standard On/Off attribute `0x4003` (read back after write) plus `0x0300:0x4010` set to `0xFFFF`, and **do not disturb** through Tuya's manufacturer-specific command `0xFA` on the standard Color Control cluster.
  That command is a deliberate, device-specific Tuya addition on a standard cluster; it is **not** the stripped `0xEF00` datapoint path and reintroduces none of it.
- `customConfigureDevice()` configures attribute reporting for on/off, level, hue, saturation, colour XY, colour temperature, and colour mode as one dispatch, and `customRefresh()` reads the same set plus the power-restore attribute as one dispatch — the two things that make hub state stop going stale.
  Group membership is not read by the driver (no library parses the Groups cluster); it is proven by driving the group device and watching the strip.
- HPM manifest with a fresh `uuidgen` id, a `repository.json` entry, the committed bundle, `just hubitat check` green, README validation-status and attribution rows, and `hubitat/AGENTS.md` rules for colour dispatch and for the DND command.
- Validation on device 36 with Live Logs open, then the same on device 35, which is the better test of the reporting claim: it has no stored state for the built-in driver to have polled, so every attribute it shows afterwards came from a report or a refresh we sent.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `hubitat-drivers`: gains requirements for colour-control dispatch through the registry (no cluster patch in `parse()`), for the colour library's observable behaviour on colour-temperature and RGB commands and reports, for the BTF LM052 driver's identity and fingerprint, for reporting configuration and refresh as single dispatches, for the power-restore and DND preferences' write-on-change semantics, and for the validation-status row the `color` library adds.
  Existing requirements are not modified.

## Impact

- **Hub-side, device 36**: moved from the built-in driver to ours for validation and kept there if it passes.
  It loses the built-in driver's per-command transition-time preferences (ours come from `level`) and gains reporting, power-restore, and DND.
  Rollback is reselecting `Advanced Zigbee RGBW Bulb`; the device holds its own settings, so nothing needs re-entering.
- **Hub-side, device 35**: the same as 36, after 36.
  It is a hub neighbour with good link quality and simply never reports; if the driver's `configure` does not make it report either, that is the finding the Risks section plans for, recorded against the device rather than worked around.
- **Hub-side, the strips' group device 52** (Groups-app child 39, DNI `Group_39`): device 36 is a member today, 35 is not, and the group device is a plain `Group Dimmer`, so whether Zigbee group messaging is on is unknown until checked.
  Because a driver swap is when the app re-sends group joins (README, units section), membership is read back from the strip after the swap rather than assumed.
- **Home Assistant (Maker API app 28)**: both strips and the group are already exposed; the bridge gains `hue`/`saturation`/`colorTemperature`/`colorMode` events that actually move.
- **Repo**: one new library, one `common` diff of three hunks (map entry, the `parse()` case, the warning exclusion), one driver directory replacing the stub, one manifest, one index entry, README and AGENTS updates.
  No Nix, no CI.
- **Sequencing**: after `hubitat-vzm31-sn-unit` (archived; its `common` entry and README matrix are the baseline) and on top of the libraries already on the hub.
  The `common` change is a compile-level change to every driver's bundle, so all bundles are regenerated and the Cube and VZM31-SN drivers are re-pushed; neither changes behaviour unless its device starts sending `0x0300`, which none does.
- **Merge touchpoint**: the concurrent change `hubitat-xiaomi-legacy-sensors` also edits `common`'s `ClustersMap` (adding `0x0403`), the README validation and attribution tables, and `hubitat/AGENTS.md`.
  Both edits to the map are single entries on different lines of the same literal; whichever lands second rebases by re-adding one entry and re-bundling.
  The changes are otherwise independent.
- **Not touched**: the `0xEF00` cluster (still unknown), Scenes and Touchlink, colour effects, `level`'s merge question with `switch`, the hub's other colour devices on built-in drivers.
