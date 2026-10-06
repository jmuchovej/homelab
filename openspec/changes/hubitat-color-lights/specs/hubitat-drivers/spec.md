## ADDED Requirements

### Requirement: Colour control dispatches through the cluster registry

The shared library's cluster registry SHALL include the Color Control cluster `0x0300`, and the shared message handler SHALL contain no cluster-specific branch for it: a `0x0300` frame SHALL reach a colour parser by the same name-based lookup every other registered cluster uses, and a read response carrying several attributes SHALL be delivered to that parser once per attribute.
A driver that does not include a colour library SHALL see a `0x0300` frame logged as a missing handler, like any other registered cluster without a parser, never as an unknown cluster and never silently.

#### Scenario: A colour report is dispatched by name

- **WHEN** a device on a driver that includes the colour library reports `0x0300:0x0007` with debug logging on
- **THEN** the log shows the frame dispatched to the Color Control parser and a `colorTemperature` event follows, with no unknown-cluster warning

#### Scenario: A multi-attribute read is delivered per attribute

- **WHEN** a read response for `0x0300` carries hue, saturation, colour temperature, and colour mode in one frame
- **THEN** each of `hue`, `saturation`, `colorTemperature`, and `colorMode` is evaluated for an event, and the log shows one parser call per attribute

#### Scenario: No patch remains in the shared handler

- **WHEN** the non-comment lines of `hubitat/libraries/common.groovy` are searched for `0x0300` and `'0300'`
- **THEN** the only match is the registry entry `0x0300: 'ColorControl'`

### Requirement: The colour library drives colour temperature and colour as the device does

The repository SHALL carry `hubitat/libraries/color.groovy`, forked from upstream's colour-temperature and RGB libraries with provenance naming both paths, declaring the `Color Control`, `Color Temperature`, `ColorMode`, `Light`, `Actuator`, and `Switch` capabilities.
Setting a colour temperature SHALL send the device a Zigbee colour-temperature command in mireds (clamped to the range the device reports, or 153–500 when unreported) so that the device enters its colour-temperature mode; it SHALL NOT imitate white by sending an RGB or XY colour.
Setting a colour SHALL send the device a hue-and-saturation command.
Reports of hue, saturation, colour X/Y, colour temperature, and colour mode SHALL become `hue`, `saturation`, `color`, `colorTemperature` (kelvin), `colorMode` (`RGB` or `CT`), and `colorName` events, with X/Y reports converted to hue and saturation.
The library SHALL NOT define level-change commands or arithmetic helpers that another library or the language already provides.

#### Scenario: Colour temperature round-trips in CT mode

- **WHEN** `setColorTemperature(4000)` is sent from the device page of an RGB+CCT strip
- **THEN** exactly one `0x0300` colour-temperature command appears in the debug log (no colour command), the strip's white channels light, and `colorTemperature` reports approximately 4000 with `colorMode` `CT`

#### Scenario: Colour round-trips with the values that were set

- **WHEN** `setColor([hue: 33, saturation: 100, level: 50])` is sent
- **THEN** the strip shows green, `hue` reports 33 and `saturation` 100, `colorMode` reports `RGB`, `color` carries the matching hex, and the hue and saturation values differ from those set by no more than rounding (±1)

#### Scenario: An XY report still yields hue and saturation

- **WHEN** the device reports `0x0300:0x0003` and `0x0004` (colour X and Y) for a pure red
- **THEN** `hue` reports approximately 0 and `saturation` approximately 100

#### Scenario: Nothing collides with the level library

- **WHEN** a driver includes both `rbn.level` and `rbn.color` and is saved on the hub
- **THEN** it compiles, and `hubitat/libraries/color.groovy` contains no definition of `startLevelChange`, `stopLevelChange`, `min`, or `max`

### Requirement: A BTF LM052 driver covers the TS0505B strip controller

The repository SHALL carry `hubitat/drivers/btf-lm052/` with a driver named `BTF LED Strip Controller (LM052)` in namespace `rbn`, built on `rbn.common`, `rbn.switch`, `rbn.level`, and `rbn.color`, declaring a fingerprint for model `TS0505B` manufacturer `_TZB210_tmi0rihb` on endpoint `01`, and declaring no catch-all fingerprint.
On a paired controller it SHALL switch, dim, set colour, and set colour temperature from the hub, and SHALL reflect changes made by other controllers (a Hubitat group, Home Assistant, a power cycle) without a refresh.
It SHALL treat cluster `0xEF00` as unknown.

#### Scenario: Hub control round-trips

- **WHEN** `on`, `setLevel(40)`, `setColor([hue: 66, saturation: 100])`, `setColorTemperature(2700)`, and `off` are sent from the device page
- **THEN** the strip follows each, and `switch`, `level`, `hue`, `saturation`, `colorMode`, and `colorTemperature` events reflect the new state

#### Scenario: External change is reflected without refresh

- **WHEN** the strip is set to level 30 through its Hubitat group device and nothing is pressed on the strip's own page
- **THEN** within the configured reporting interval the strip's `level` reports 30

#### Scenario: A joining strip is offered the driver

- **WHEN** a controller with model `TS0505B` and manufacturer `_TZB210_tmi0rihb` joins the hub
- **THEN** the hub selects `BTF LED Strip Controller (LM052)` for it by fingerprint

#### Scenario: Tuya datapoint cluster stays unknown

- **WHEN** a frame on cluster `0xEF00` arrives from the strip with debug logging on
- **THEN** the log reports an unknown cluster and no datapoint processing occurs

### Requirement: Reporting configuration and refresh are each one dispatch

`configure` on the LM052 driver SHALL send, as one dispatch, attribute-reporting configuration for on/off, level, hue, saturation, colour X, colour Y, colour temperature, and colour mode, plus reads of the device's colour capabilities and colour-temperature range, and SHALL write no preference-backed attribute and send no manufacturer-specific command.
`refresh` SHALL send, as one dispatch, reads of on/off, level, the colour attributes above, and the power-restore attribute.

#### Scenario: Configure is one dispatch with no writes

- **WHEN** `configure` is pressed with debug logging on
- **THEN** exactly one `sendZigbeeCommands: sent cmd=` line appears, it contains Configure Reporting for `0x0006`, `0x0008`, and the six `0x0300` attributes, and it contains no write to `0x4003`, no write to `0x4010`, and no `0x0300` command `0xFA`

#### Scenario: Refresh is one dispatch covering state and power restore

- **WHEN** `refresh` is pressed with debug logging on
- **THEN** exactly one `sendZigbeeCommands: sent cmd=` line appears for it, its list reads `0x0006:0x0000`, `0x0008:0x0000`, the `0x0300` attributes `0x0000`, `0x0001`, `0x0003`, `0x0004`, `0x0007`, `0x0008`, and `0x0006:0x4003`, and the corresponding events follow

#### Scenario: Reporting makes state stick

- **WHEN** `configure` has run once and the strip is afterwards changed from Home Assistant
- **THEN** the hub's `switch`, `level`, and colour attributes update from reports and the device does not fall to `INACTIVE` while powered

### Requirement: Power-restore and do-not-disturb are preferences the device owns

The LM052 driver SHALL expose a power-restore preference (off, on, last state) backed by the standard On/Off attribute `0x4003`, and a do-not-disturb preference backed by Tuya's manufacturer-specific command `0xFA` on the Color Control cluster, and SHALL expose no Tuya datapoint surface.
`refresh` SHALL read `0x4003` and set the preference to the value the device reports.
Saving preferences SHALL write `0x4003` (and set `0x0300:0x4010` to `0xFFFF`) only when the power-restore preference differs from the last value read, and SHALL read it back; it SHALL send the `0xFA` command only when the do-not-disturb preference differs from the last value sent, recording what was sent, since the device offers no read-back for it.
`configure` SHALL write neither.

#### Scenario: Power restore reflects the device

- **WHEN** a strip whose power-restore behaviour is "last state" is moved onto the driver, preferences are saved once untouched, and `refresh` is pressed
- **THEN** the power-restore preference shows "last state" and the log contains no write to `0x4003`

#### Scenario: Only a changed power-restore is written

- **WHEN** the user changes power restore to "on" and saves preferences
- **THEN** the log shows one write of `0x4003`, one write of `0x0300:0x4010`, one read of `0x4003`, and no `0xFA` command

#### Scenario: Do-not-disturb is one standard-cluster command

- **WHEN** the user enables do-not-disturb and saves preferences
- **THEN** the log shows exactly one `0x0300` command `0xFA` with payload `01`, no frame on `0xEF00`, and no write to `0x4003`; saving again without change sends nothing

#### Scenario: Configure writes neither preference

- **WHEN** `configure` is pressed on a strip with power restore "on" and do-not-disturb enabled
- **THEN** no `0x4003` write and no `0xFA` command appear in the log, and the strip still restores to "on" after a power cycle

### Requirement: The colour library's validation and provenance are recorded

`hubitat/README.md` SHALL carry a validation-status row for `color` stating whether it is runtime-verified, on which device, and when, and an attribution row for `hubitat/libraries/color.groovy` naming both upstream paths and the commit.
`hubitat/AGENTS.md` SHALL state that the Color Control cluster is dispatched through the registry with no handler patch, and that the do-not-disturb command is a deliberate device-specific Tuya command on a standard cluster, distinct from the stripped `0xEF00` path.

#### Scenario: Status matrix after the strip run

- **WHEN** the LM052 validation has completed on one strip
- **THEN** the README lists `color` as runtime-verified on the LM052 with the date, and the eight existing rows are unchanged

#### Scenario: Attribution names both sources

- **WHEN** the README attribution table is read
- **THEN** it has a row for `libraries/color.groovy` naming `Libraries/ctLib.groovy` and `Libraries/rgbLib.groovy` at commit `0bf47407` and summarising the modifications
