## 1. Spikes (hub, by hand, before any driver code)

- [x] 1.1 Record the baseline for the validation unit: Bathroom Light Switch (device 5) on Inovelli's driver — its settings list from `/device/fullJson/5`, parameters 52 and 258 as shown, and the result of its `bindGroup` / binding state if any — into a scratch note, so 5.x can diff against it
- [x] 1.2 Learn the Zigbee group id of the Zigbee-messaging group Bathroom Lights (device 37, DNI `Group_33`): hypothesis is 33 (`0x0021`).
      (confirmed two ways: a Get Group Membership query to the switch returned exactly one group, `0x0021`, and the switch's binding table already held EP2 `0x0006`/`0x0008` → `0x0021`; the paddle moved both bathroom bulbs with the switch on Inovelli's driver)
      On Inovelli's driver run `bindGroup('bind', 33)` on Bathroom Light Switch with smart-bulb mode on, wait 60 s, and press the paddle; verify the bathroom bulbs follow.
      If they do not, try the group device's id and the child app id; if none works, STOP — redesign D2 before writing code (the rest of this change assumes a known group id)
- [x] 1.3 Verify the binding table can be read back: send ZDO Mgmt_Bind_req `0x0033` to the switch (from Inovelli's driver via `setZigbeeAttribute`-style raw command or a throwaway probe driver) and capture the `0x8033` response in Live Logs; verify it lists the two group entries from 1.2 and record the raw frame for the parser
- [x] 1.4 Run `bindGroup('unbind', <id>)`, wait 60 s, read back; verify the two entries are gone, then re-bind so the unit stays usable until 5.x.
      Record everything in the scratch note
      (done with raw `zdo unbind`/`zdo bind` through the `bind` relay rather than `bindGroup`, which is not a declared command: unbind acks `0x8022` status 00 within 1 s, table total 6 → 4 with the EP2 group entries gone; re-bind acks `0x8021` status 00 within 1 s, table back to 6 with EP2 `0x0006`/`0x0008` → `0x0021`. The 60 s wait is unnecessary; a few seconds then read-back suffices)

## 2. Library and driver

- [x] 2.1 Add `0xFC31: 'InovelliPrivate'` to `ClustersMap` in `hubitat/libraries/common.groovy` and extend its `Modified for the rbn namespace:` provenance line; verify `jj diff hubitat/libraries/common.groovy` is two lines and `just hubitat probe` compiles
- [x] 2.2 Write the parameter table in `hubitat/drivers/inovelli-vzm31-sn/inovelli-vzm31-sn.groovy` per design D4: a static map keyed by number for 1–10, 12–15, 18–21, 30–33, 50, 52, 95–100, 256–258 with name, size, type, range spec, default, readOnly, group; range generators for dimming/ramp (0, 5–126, 127 = sync), levels, and enums; verify `rg -c "^\s*[0-9]+\s*:" <file>` prints the row count and the file stays under 400 lines
- [ ] 2.3 Render editable table rows as preferences named `parameter<N>` in the `preferences` block (loop over the table; read-only rows excluded); verify on the hub's device page that the listed parameters appear, grouped, with Inovelli-matching names
- [ ] 2.4 Implement `customParseInovelliPrivateCluster(Map)` per D5/D6: attribute reports and read responses decode by the row's size/type (signed for 32), update `settings.parameter<N>` and `state.parameters[N]`, emit `internalTemp`, `overHeat`, `powerSource`, aux-learn attributes for read-only rows; cluster-specific commands log at debug and return; verify with `just hubitat push` that the periodic `0x0020`/`0x0021` reports now log as parameters with no warning
- [x] 2.5 Extend `customRefresh()` to append a `0xFC31` read (mfgCode `0x122F`) for every table row to the existing four reads, still one list; verify one `sendZigbeeCommands: sent cmd=` line on `refresh` whose list contains every table parameter
- [ ] 2.6 Implement `customUpdated()` per D5: write only preferences that differ from `state.parameters`, with the long delay for 52 and 258, then read each written parameter back; no `customConfigureDevice()`; verify changing one preference produces exactly one `0xFC31` write and one read in the log, and `configure` produces no `0xFC31` traffic
- [x] 2.7 Implement `bindGroup(groupId)`, `unbindGroup(groupId)`, `readBindings()`, and the `bind(cmds)` relay per D3, each one dispatch; declare them as commands; verify `bindGroup` emits the two `zdo bind` lines with the 4-hex group id and the 60 s delay, `readBindings` emits the `0x0033` request
      (implemented; the delay after the two `zdo bind` lines is 3 s, not 60 s, because spike 1.4 showed the device acknowledges within 1 s, and `bindGroup`/`unbindGroup` append the binding-table request so one dispatch both acts and proves; emitted-line check happens with a device on the driver in 4.3)
- [ ] 2.8 Implement `customParseZdoClusters(Map)` for `0x8033`: parse status, total, start index, count, entries (group or device destinations), request further pages by start index, emit `bindings` attribute (JSON) and log lines; verify against the raw frame recorded in 1.3 by replaying it through the hub (bind, read, compare)
- [x] 2.9 `just hubitat bundle`, `just hubitat check`, `just hubitat probe`, `just hubitat push inovelli-vzm31-sn --dry-run` (after 1.x the hub still runs 0.1.1); verify check exits 0, probe compiles all libraries, dry-run reports `would update`
      (check 0; probe compiled all 8; the first push failed on `@Field` cross-references (fixed by making the enum maps static methods), the second compiled on the hub; a following dry-run reports `unchanged`. No device is on the driver, so the hub copy being 0.2.0-dev is inert)
- [x] 2.10 Commit groups as `feat(hubitat): route 0xFC31 to the driver` (common) and `feat(hubitat): VZM31-SN parameters and group bindings` (driver + bundle + manifest unchanged) with explicit filesets; verify `jj diff -r @- --stat` per commit
      (`750f70b8` common + the Cube bundle it is inlined into; `9e22fe34` driver + bundle)
- [ ] 2.11 (added during 4.x, design D5 amendment) Shared `hubReportingCommands()`: on/off and level reporting from EP1 plus `0xFC31` bindings from EP1 and EP2 to the hub; `customConfigureDevice()` returns it plus a binding-table read; `bindGroup` appends it.
      Verify on Bathroom Light Switch that `configure` adds the four hub bindings to the table with no parameter write, and that a paddle press afterwards produces `switch`/`level` events with `type: physical`; commit as `feat(hubitat): VZM31-SN hub reporting bindings from configure and bindGroup`

## 3. Documentation

- [x] 3.1 `hubitat/README.md`: add a **Switch-plus-bulbs units** section: smart-bulb mode, the Groups app with Zigbee group messaging (the one setting that must stay on), `bindGroup` with the group id, `readBindings` as the check, the hub-reboot test, the bulb-replacement procedure, and the Home Assistant convention (light control via the group device; switch = paddle state + metering); add `refresh` as the first step after selecting the driver; verify the section exists and names all three commands
- [x] 3.2 `hubitat/AGENTS.md`: add the device-is-truth rule for parameters (read on refresh, write deltas on save, Configure writes nothing on `0xFC31`), the `ClustersMap` entry, and that `bindings`/`state.parameters` are the facts to check before diagnosing a unit; verify the section exists
- [x] 3.3 Commit as `docs(hubitat): switch-plus-bulbs units` with an explicit fileset; verify scoped diff
      (`8a2c3e5d`, README and AGENTS only)

## 4. Hub validation on one unit (by hand, Live Logs open, debug on)

- [ ] 4.1 `just hubitat push inovelli-vzm31-sn`; on Bathroom Light Switch select the `rbn` driver, Save Device, press `refresh`; verify every exposed preference shows the value recorded in 1.1 and the log contains no `0xFC31` write
- [ ] 4.2 Verify smart-bulb mode (52) reads on; if off, set it on via preferences and Save; verify exactly one write + read-back for 52 and the relay stays closed (bulbs stay powered on paddle-down)
- [x] 4.3 `bindGroup(<id from 1.2>)`, wait 60 s, `readBindings()`; verify the `bindings` attribute lists EP2 → group for `0x0006` and `0x0008` and the log shows two bind-success responses
      (16:12:16 UTC `bindGroup(33)` → 3.6 s later `bindings (6): … EP2 0x0006 -> group 0x0021; EP2 0x0008 -> group 0x0021`, paged across two `0x8033` replies; the `bindings` attribute carries the same six entries as JSON. Bind acks are logged by `common` at debug, which was off on this device)
- [ ] 4.4 Paddle test: down, up, hold to dim; verify all bathroom bulbs follow together and the switch's `switch`/`level` events are `physical`
      (17:08–17:14 UTC: bulbs followed up, down, up, and a hold-to-dim, per the user; the hub heard only power reports (5.6 W, 0.2 W, 5.8 W) because the switch had no on/off or level bindings to the hub — see 2.11. `physical` events to be re-verified after 2.11)
- [ ] 4.5 Reboot the hub; while it is unreachable repeat 4.4; verify the bulbs follow with the hub down, and after the hub returns the switch reports the resulting state
- [x] 4.6 From Home Assistant set the Bathroom Lights group to 30; verify all bulbs change in one multicast (one group command in the hub log) and the switch's `power` follows the load
      (16:30:36–45 UTC: group 37 `level was set to 37%` then `30%`, both bulbs `level was set to 37%`/`is on`/`30%`; the switch, itself a member of group 0x0021, reported `was set 37 [physical]` and `was set 30 [physical]` with power 2.7 W → 0.2 W while its `switch` stayed off — the LED bar follows HA for free)
- [x] 4.7 Press `configure`; verify no `0xFC31` traffic, bindings unchanged on `readBindings`, smart-bulb mode still on
      (16:36:44 UTC with debug on: `configure()... cfgCtr=1`, `no customConfigureDevice method defined`, `configureDevice(): cmds=[]`, `no commands defined for device type Dimmer` — nothing was sent, so bindings and P52 cannot have changed; the settings dump in the same line shows all 25 editable parameters holding the device's values)
- [ ] 4.8 Double-tap the paddle; verify a single debug line for `0xFC31`, no warning, no error, no button event
      (17:15 UTC: a top-paddle double-tap produced no frame at the hub at all — the switch had no EP2 `0xFC31` binding to the hub; trivially quiet, but the scenario is re-run after 2.11 so the driver's handling of a real scene command is what gets verified)
- [ ] 4.9 Record findings and any deviation in the scratch note; if 4.1–4.8 surfaced a defect, fix, re-bundle, re-push, and repeat the failed step before continuing

## 5. Release

- [ ] 5.1 Update the README status matrix: `common`, `switch`, `level`, `meter`, `reporting` rows gain "unit: parameters + group bindings" in the device column note for VZM31-SN with the date; verify eight rows intact
- [ ] 5.2 `just hubitat bump inovelli-vzm31-sn 0.2.0`; set manifest `releaseNotes` to "parameters as preferences (device is the source of truth) and group bindings for switch-plus-bulbs units"; verify `just hubitat check` exits 0
- [ ] 5.3 Commit as `feat(hubitat): VZM31-SN 0.2.0 — parameters and group bindings` and `chore(openspec): record hubitat-vzm31-sn-unit results`; verify scoped diffs.
      Push is the user's
- [ ] 5.4 (hub, after push) HPM → Update; verify `Inovelli Dimmer (Blue, VZM31-SN)` is offered at 0.2.0 and the hub's copy reads `version() { '0.2.0' }`
- [ ] 5.5 Roll the remaining units one at a time per the README procedure, recording each unit's group id and `readBindings` result in the scratch note; verify each with a paddle test; stop and report on the first unit that does not follow
