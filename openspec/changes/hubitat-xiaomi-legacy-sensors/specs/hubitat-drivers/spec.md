## ADDED Requirements

### Requirement: The pressure cluster is dispatched like any other standard cluster

The shared message handler SHALL recognise cluster `0x0403` (Pressure Measurement) so that a report on it reaches a driver's pressure parser rather than being logged as an unknown cluster.
A driver that measures pressure SHALL emit `pressure` in hPa from attribute `0x0000` and SHALL ignore values outside 500–2000 hPa.

#### Scenario: Pressure report reaches the driver

- **WHEN** a weather sensor reports `0x0403:0x0000` raw `0x03F9` (1017) with debug logging on
- **THEN** a `pressure` event of `1017` hPa is emitted and the log contains no unknown-cluster warning for `0x0403`

#### Scenario: Implausible pressure is dropped

- **WHEN** the sensor reports `0x0403:0x0000` raw `0x0000`
- **THEN** no `pressure` event is emitted and the log notes the ignored value

### Requirement: The legacy Xiaomi struct yields battery events

For a device whose model begins with `lumi`, the shared libraries SHALL decode Basic-cluster attributes `0xFF01` and `0xFF02` as the Xiaomi tag/type/value struct and SHALL emit `batteryVoltage` in volts from the voltage tag (millivolts on the wire), plus `battery` as a percentage when voltage-to-percent conversion is enabled, through the same battery path the Power Configuration cluster uses.
The struct SHALL be received as hex regardless of the device typing it as a character string.
Tags the shared libraries do not interpret SHALL be offered to the driver and otherwise logged at debug, never as an error.

#### Scenario: Hourly check-in reports battery

- **WHEN** a sensor sends its periodic `0xFF01` report whose voltage tag reads `0x0BD1` (3025 mV)
- **THEN** `batteryVoltage` is `3.0` V, `battery` is a percentage derived from it, `lastBattery` is updated, and the log shows the struct parsed with no warning

#### Scenario: Struct value is hex, not characters

- **WHEN** a `0xFF01` report arrives with debug logging on
- **THEN** the logged `descMap` for it shows a hexadecimal `value`, and the decoder is not applied to a non-Xiaomi device's `0xFF01`

#### Scenario: Unknown tags are quiet

- **WHEN** the struct carries a tag the libraries do not interpret
- **THEN** the log shows at most a debug line naming the tag, and no `error` or `warn` line results from it

### Requirement: Contact comes from the On/Off cluster without a switch capability

A door/window sensor driver SHALL emit `contact` (`open` when the On/Off attribute is `1`, `closed` when `0`) from cluster `0x0006` attribute `0x0000`, SHALL declare `ContactSensor`, and SHALL NOT declare `Switch` or `Actuator` nor offer `on`/`off` commands.
The same `contact` value carried in the periodic struct SHALL update the attribute so that a missed report is corrected at the next check-in.

#### Scenario: Open and close are reflected

- **WHEN** the magnet is separated from the sensor and then returned
- **THEN** a `contact: open` event follows the first action and `contact: closed` the second, each with `type: physical`

#### Scenario: No switch surface

- **WHEN** the device page of a sensor on the driver is inspected
- **THEN** its capabilities list `ContactSensor` and `Battery` and not `Switch`, and no `on` or `off` command button is shown

#### Scenario: Check-in corrects contact

- **WHEN** the periodic struct reports the contact tag as `1` while the attribute reads `closed`
- **THEN** `contact` becomes `open`

### Requirement: Drivers for the WSDCGQ11LM and MCCGQ11LM carry the upstream fingerprints

The repository SHALL carry `hubitat/drivers/aqara-wsdcgq11lm/` with a driver named `Aqara Temperature and Humidity Sensor (WSDCGQ11LM)` declaring fingerprint manufacturer `LUMI` model `lumi.weather` (`inClusters 0000,0003,FFFF,0402,0403,0405`, `outClusters 0000,0004,FFFF`), and `hubitat/drivers/aqara-mccgq11lm/` with a driver named `Aqara Door and Window Sensor (MCCGQ11LM)` declaring fingerprint manufacturer `LUMI` model `lumi.sensor_magnet.aq2` (`endpointId 01`, `profileId 0104`, `deviceId 5F01`, `inClusters 0000,0003,FFFF,0006`, `outClusters 0000,0004,FFFF`), both in namespace `rbn`, each with a manifest, an index entry, and a committed bundle.
The weather driver SHALL emit `temperature`, `humidity`, and `pressure` with user offsets applied to the first two; its preference page SHALL offer the offsets and SHALL NOT offer reporting-interval settings.
`refresh` on either driver SHALL be one dispatch of its standard reads, and `configure` SHALL send no command.
The tree SHALL contain no driver directory named for a seller's listing code.

#### Scenario: Paired sensor is offered the driver

- **WHEN** a `lumi.weather` or `lumi.sensor_magnet.aq2` device joins the hub with the drivers installed
- **THEN** the hub selects the matching `rbn` driver by fingerprint

#### Scenario: Weather readings carry offsets

- **WHEN** the temperature offset is set to `-0.5`, preferences are saved, and the sensor reports `0x0402:0x0000` raw `0x0960` (24.00 °C) and `0x0405:0x0000` raw `0x1388` (50.00 %)
- **THEN** `temperature` is `23.5` in the hub's scale and `humidity` is `50` % RH

#### Scenario: No reporting intervals are offered or written

- **WHEN** the weather driver's preference page is opened with Advanced Options on, and `configure` is then pressed
- **THEN** the page shows no minimum or maximum reporting-interval input, and the log shows `configure` sent no command

#### Scenario: Refresh is one dispatch

- **WHEN** `refresh` is invoked on the weather driver with debug logging on
- **THEN** exactly one `sendZigbeeCommands: sent cmd=` line appears, listing reads of `0x0402`, `0x0403`, and `0x0405`; a reply is not required, and a sleeping device yields only the library's no-response warning

#### Scenario: Aqara directories are named for the model

- **WHEN** `hubitat/drivers/` is listed
- **THEN** the Aqara directories are `aqara-cube-t1-pro`, `aqara-wsdcgq11lm`, and `aqara-mccgq11lm`, none carries a seller's code such as `t007`, and `just hubitat check` exits zero

### Requirement: Check-in-only devices get an honest health status

A driver for a device that only reports on its own schedule SHALL use the activity-based health check, SHALL default its check interval to one hour on full initialisation, and SHALL report `healthStatus: offline` once the library's missed-check threshold is reached and `online` again on the next message, with no operator action.
`hubitat/README.md` SHALL state that a driver swap needs one Save Preferences, with the interval chosen in it, before any check is scheduled.

#### Scenario: Silence becomes offline

- **WHEN** a sensor's battery is removed and the check interval is 2 minutes
- **THEN** `healthStatus` becomes `offline` within 8 minutes, and after the battery is replaced and the sensor's button pressed it becomes `online` on that message

#### Scenario: Scheduling is confirmed on save

- **WHEN** the interval is set to Every 1 Hour and preferences are saved
- **THEN** the log shows the health check scheduled every 60 minutes by the activity method

#### Scenario: Polling is not used

- **WHEN** the health check runs on a sleeping sensor
- **THEN** no read or ping is sent to the device for the check

### Requirement: Validation status covers the two new libraries

`hubitat/README.md` SHALL carry `temperature` and `humidity` rows in the validation-status matrix, each `compile-verified` until a paired WSDCGQ11LM has exercised them and `runtime-verified` with the device and date afterwards, and SHALL list both forked libraries in the attribution table with upstream path and commit.
The `xiaomi` attribution row SHALL name the legacy-struct decoder rather than "identity only".

#### Scenario: Matrix after the weather run

- **WHEN** the WSDCGQ11LM validation has completed
- **THEN** the README lists `temperature` and `humidity` as runtime-verified on WSDCGQ11LM with the date, ten rows in all

#### Scenario: Attribution is current

- **WHEN** the attribution table is read
- **THEN** it has rows for `libraries/temperature.groovy` (`Libraries/temperatureLib.groovy`, `0bf47407`) and `libraries/humidity.groovy` (`Libraries/humidityLib.groovy`, `0bf47407`), and the `xiaomi` row's modification column names the `0xFF01` decoder
