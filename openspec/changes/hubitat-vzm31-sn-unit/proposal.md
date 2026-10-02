## Why

Ten Inovelli VZM31-SN dimmers sit upstream of one to three Philips Hue or IKEA Trådfri bulbs each, and a switch plus its bulbs should behave as one unit: the paddle dims the bulbs, Home Assistant controls both, and none of that depends on the hub being up.
The third-party Zigbee Bindings app that tried to do this against Inovelli's driver gave mixed results, and the `rbn` driver released in `hubitat-runtime-validation` (0.1.1) covers only the standard clusters — it cannot set smart-bulb mode, dimming or ramp timing, min/max level, or reporting, and it cannot bind.
Now that the libraries, the driver, and the HPM path are all ours, the unit can be built from the parts that actually work and verified end to end rather than patched.

## What Changes

- The `Inovelli Dimmer (Blue, VZM31-SN)` driver learns Inovelli's private cluster `0xFC31` for **parameters**: a generated parameter table (number, size, type, range, default, read-only) rendered as preferences, read from the device on install and refresh, written only when a preference actually changed.
  The device is the source of truth; neither Configure nor Save Preferences ever writes a default the user did not set, so a configured unit is never silently reset.
  In scope now: smart-bulb mode (52), switch mode (258), dimming and ramp speeds (1–8), min/max level (9–10), default levels and power-restore level (13–15), auto-off timer (12), button press delay (50), power and energy reporting (18–20), the read-only diagnostics (21, 30–33), local protection (257), and the LED bar as a whole (96–100).
  Not now: per-LED colours and notifications (60–95), fan and aux parameters (121–134, 256), the long tail.
- The driver gains **binding commands**: bind and unbind its remote endpoint (EP2, clusters `0x0006` and `0x0008`) to a Zigbee **group**, and read the switch's binding table back so the state of a unit is a fact, not a hope.
  A `bind(cmds)` relay stays for compatibility with raw-command tools.
- The unit is **group-based**: bulbs are members of a Zigbee group, the switch is bound to that group, and the bulbs' membership comes from Hubitat's built-in Groups and Scenes app with Zigbee group messaging on — three such groups already exist on the hub.
  No custom app is written in this change.
- `common`'s `ClustersMap` gains `0xFC31`, which routes the cluster to the driver's parser; scene-button commands on that cluster are logged at debug and ignored until the follow-up change adds button events.
- **BREAKING** for the spec, not for devices: the previous requirement that the driver treats `0xFC31` as unknown is replaced.
  Hub control, physical reflection, metering scale, and single-dispatch refresh keep their scenarios.
- README and `hubitat/AGENTS.md` document the unit: topology, the Groups-app dependency, the Home Assistant convention (control the bulb group for light, read the switch for paddle state and metering), and the recovery steps when a bulb is replaced.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `hubitat-drivers`: the VZM31-SN driver requirement changes from "standard clusters, `0xFC31` unknown" to "standard clusters plus parameters and group bindings on `0xFC31`"; new requirements cover device-is-truth parameter semantics, group binding with read-back, and hub-independent unit operation.

## Impact

- **Hub-side, all ten dimmers over time**: moved from Inovelli's driver to ours.
  Parameters live on the device, so the move changes nothing until a preference is deliberately saved.
  Rollback remains a driver reselect.
- **Hub-side, Hue and Trådfri bulbs**: added to Zigbee-messaging groups through the built-in Groups app, which also gives Home Assistant one light entity per unit.
  Bulbs keep their existing drivers.
- **Hub-side, hub outage**: once bound, paddle control of the bulbs needs no hub; this is verified by rebooting the hub mid-test.
- **Home Assistant (Maker API)**: gains the group devices as lights; the switch stays a light plus power and energy sensors.
  In smart-bulb mode the switch's own on/off and level reflect the paddle, not the load, which the README states as the HA convention.
- **Repo**: driver grows a parameter table and parsers (kept well under the 64 KB method limit by generating ranges rather than spelling them out), `common` gains one `ClustersMap` entry, README and AGENTS updated, driver bumped and released through HPM.
  There is no Groovy test runner in the tree; the compile checks are `probe` and `push`, and behaviour is verified on the hub per the specs.
- **Spikes before code**: the Hubitat `zdo bind` syntax for a group destination (present in Inovelli's driver as `bindGroup`, unverified on this hub) and how to learn the Zigbee group id a Groups-app group uses (its device data is empty; the DNI `Group_<n>` is the lead).
  Both are hub tasks with no repo change.
- **Not touched**: scene buttons and LED effects (next change), the `switch`/`level` merge question, `deviceProfileLib`, the third-party bindings app (left installed, unused).
