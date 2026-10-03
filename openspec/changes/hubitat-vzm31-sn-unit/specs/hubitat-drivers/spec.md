## MODIFIED Requirements

### Requirement: A minimal VZM31-SN driver covers the standard clusters

The repository SHALL carry `hubitat/drivers/inovelli-vzm31-sn/` with a driver named `Inovelli Dimmer (Blue, VZM31-SN)` in namespace `rbn`, built on `rbn.common`, `rbn.switch`, `rbn.level`, `rbn.meter`, and `rbn.reporting`, declaring the upstream fingerprints for model `VZM31-SN` manufacturer `Inovelli`.
On a paired dimmer it SHALL switch and dim from the hub, reflect physical switching and dimming, report energy in kWh (device value ÷ 100) and power in W (device value ÷ 10), and send no Configure Reporting commands unless Configure is explicitly invoked.
It SHALL recognise Inovelli's private cluster `0xFC31`: attribute reports on it are parameter values and are parsed; commands on it that the driver does not implement (scene-button events) are logged at debug level and produce no event and no error.

#### Scenario: Hub control round-trips

- **WHEN** `on`, `off`, and `setLevel(40)` are sent from the device page
- **THEN** the dimmer responds and `switch` and `level` events reflect the new state

#### Scenario: Physical control is reflected

- **WHEN** the paddle is pressed up, pressed down, and held to dim
- **THEN** `switch` and `level` events update with `type: physical`

#### Scenario: Refresh is one dispatch covering all four readings

- **WHEN** `refresh` is invoked with debug logging on
- **THEN** exactly one `sendZigbeeCommands: sent cmd=` line appears for it, its list reads on/off, level, `0x0702:0x0000`, and `0x0B04:0x050B`, and `switch`, `level`, `energy`, and `power` events follow

#### Scenario: Metering scale is correct

- **WHEN** the dimmer reports `0x0B04:0x050B` raw `0x0096` (150) and `0x0702:0x0000` raw `0x000000000A28` (2600)
- **THEN** `power` is `15.0` W and `energy` is `26.00` kWh

#### Scenario: Private cluster is ignored, not errored

- **WHEN** the paddle is double-tapped (an Inovelli `0xFC31` scene command)
- **THEN** the log shows at most a debug line naming `0xFC31`, no warning, no `error` line, and no button event

#### Scenario: No reporting changes without Configure

- **WHEN** the device is moved onto the driver, refreshed, switched, and dimmed, and Configure is never pressed
- **THEN** the debug log contains no Configure Reporting command for `0x0702` or `0x0B04`

## ADDED Requirements

### Requirement: VZM31-SN parameters are preferences whose source of truth is the device

The driver SHALL expose a defined set of Inovelli parameters as device preferences: smart-bulb mode (52), switch mode (258), dimming and ramp speeds (1–8), minimum and maximum level (9–10), auto-off timer (12), default and power-restore levels (13–15), power and energy reporting (18–20), button press delay (50), local protection (256), and LED-bar colour, intensity, notification, and scaling for the bar as a whole (95–100).
Read-only parameters (power source 21, aux learn values 30–31, internal temperature 32, overheat 33, remote protection 257) SHALL be reported as attributes or state, never offered for editing.
The driver SHALL read every exposed parameter from the device when the driver is first selected and on `refresh`, and SHALL set each preference to the value the device reports.
Saving preferences SHALL write only parameters whose preference value differs from the value last read from the device, and SHALL read each written parameter back.
Neither `configure` nor saving preferences SHALL write a parameter the user has not changed, so defaults are never applied over a device's existing configuration.

#### Scenario: Preferences reflect the device after selection

- **WHEN** a dimmer with smart-bulb mode on and a 1.0 s remote dimming speed is moved onto the driver and `refresh` is pressed
- **THEN** the smart-bulb-mode preference shows on and the remote dimming speed shows 1.0 s without the user saving anything, and the log contains no parameter write

#### Scenario: Only the changed parameter is written

- **WHEN** the user changes only the maximum level to 90 and saves preferences
- **THEN** the log shows one `0xFC31` write for parameter 10, one read of parameter 10, and no write of any other parameter

#### Scenario: Configure does not reset a unit

- **WHEN** `configure` is pressed on a dimmer whose smart-bulb mode is on and whose bindings are in place
- **THEN** no parameter write appears in the log, smart-bulb mode is still on, and the bindings are unchanged

#### Scenario: Read-only parameters are visible but not editable

- **WHEN** the device reports internal temperature (32) and power source (21)
- **THEN** both appear as attributes on the device page and neither appears among the editable preferences

### Requirement: VZM31-SN group bindings are commands with a verifiable result

The driver SHALL offer commands to bind and to unbind the switch's remote endpoint (endpoint 2) to a 16-bit Zigbee group for the on/off (`0x0006`) and level (`0x0008`) clusters, and a command to read the switch's binding table back, reporting each entry's source endpoint, cluster, and destination (group id or device address and endpoint) as a device attribute and in the log.
Binding and unbinding SHALL be issued as one dispatch each.
The driver SHALL also accept raw binding commands through a `bind(cmds)` relay for tools that construct them.
`configure` SHALL create the switch's reporting bindings to the hub — on/off and level from endpoint 1 with reporting configuration, and the private cluster from endpoints 1 and 2 — and nothing else; the bind-to-group command SHALL reapply the same bindings, so a switch that has been configured or bound reports paddle actions to the hub.

#### Scenario: Configure installs hub reporting and nothing else

- **WHEN** `configure` is pressed on a switch whose binding table lacks on/off and level bindings to the hub
- **THEN** the table read back afterwards contains endpoint 1 on/off, level, and private-cluster bindings and an endpoint 2 private-cluster binding to the hub, no parameter write appears in the log, and a following paddle press produces `switch`/`level` events with `type: physical`

#### Scenario: Binding to a group is recorded on the switch

- **WHEN** the bind-to-group command is invoked with group `0x1234` and the binding table is then read back
- **THEN** the table reports two entries from endpoint 2 to group `0x1234`, one for `0x0006` and one for `0x0008`, and the log shows a bind success response for each

#### Scenario: Unbinding removes exactly those entries

- **WHEN** the unbind-from-group command is invoked with the same group and the binding table is read back
- **THEN** neither entry is present and any other entries are unchanged

#### Scenario: Read-back is the truth, not the last command

- **WHEN** the binding table is read on a switch that was never bound
- **THEN** the driver reports an empty table rather than any previously requested binding

### Requirement: A switch-plus-bulbs unit operates without the hub

With smart-bulb mode on, the switch bound to a Zigbee group, and the unit's bulbs members of that group, the paddle SHALL turn the bulbs on and off and dim them with no hub involvement, and this SHALL hold while the hub is rebooting or offline.
The switch's own `switch` and `level` attributes SHALL reflect the paddle's last action, and its `power` and `energy` SHALL continue to meter the load.
Hub-initiated control of the unit's light output SHALL be through the bulb group; hub-initiated changes to the bulbs are not required to be reflected on the switch.

#### Scenario: Paddle controls the bulbs with the hub down

- **WHEN** the hub is rebooted and, while it is unreachable, the paddle is pressed down, pressed up, and held to dim
- **THEN** the unit's bulbs turn off, turn on, and dim accordingly, and after the hub returns the switch reports the resulting `switch` and `level`

#### Scenario: Group control from the hub moves all bulbs together

- **WHEN** the unit's group device is set to level 30 from the hub
- **THEN** every bulb in the unit changes to 30 in one multicast and the switch's power reading follows the new load

#### Scenario: Smart-bulb mode keeps the bulbs powered

- **WHEN** the paddle is pressed down on a unit with smart-bulb mode on
- **THEN** the bulbs turn off by command and remain powered, and the switch's relay does not open

### Requirement: The unit is documented for operators and Home Assistant

`hubitat/README.md` SHALL describe how a unit is assembled (smart-bulb mode, the bulb group through Hubitat's Groups and Scenes app with Zigbee group messaging, the bind-to-group command, and the read-back check), what to do when a bulb is replaced, and the Home Assistant convention that light control targets the bulb group while the switch provides paddle state and metering.
`hubitat/AGENTS.md` SHALL state the device-is-truth rule for parameters and that Configure must never write defaults.

#### Scenario: Replacing a bulb has a written procedure

- **WHEN** an operator reads the README after replacing one bulb in a unit
- **THEN** they find the steps that return the unit to a verified state, ending with the binding-table read-back and a paddle test
