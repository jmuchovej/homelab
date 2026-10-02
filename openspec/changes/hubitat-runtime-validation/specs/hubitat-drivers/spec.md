## ADDED Requirements

### Requirement: Each driver ships a Hubitat Package Manager manifest

Every driver directory `hubitat/drivers/<driver>/` SHALL contain a `packageManifest.json` whose single `drivers[]` entry has `namespace` `rbn`, a `name` equal to the driver's `definition` name, a `location` that is the raw GitHub URL of `hubitat/drivers/<driver>/<driver>.bundled.groovy` on the repository's default branch, and a stable UUID `id` that is never changed once published.
The manifest's `version` SHALL equal the driver's `version()`.
`just hubitat check` SHALL exit non-zero, naming the file, when any of these disagree.

#### Scenario: Manifest agrees with its driver

- **WHEN** a driver's `version()` is `0.1.0`, its manifest `version` is `0.1.0`, and the manifest `location` names the bundle beside it
- **THEN** `just hubitat check` exits zero

#### Scenario: Version drift is refused

- **WHEN** a driver's `version()` is changed to `0.1.1` and its manifest still says `0.1.0`
- **THEN** `just hubitat check` exits non-zero and names that `packageManifest.json`

#### Scenario: Wrong location or identity is refused

- **WHEN** a manifest's `location` does not end in `/hubitat/drivers/<driver>/<driver>.bundled.groovy`, or its `name`/`namespace` differ from the driver's `definition`
- **THEN** `just hubitat check` exits non-zero and names that `packageManifest.json`

#### Scenario: Install from a manifest URL

- **WHEN** the manifest's raw URL is pasted into HPM → Install → From a URL
- **THEN** HPM installs the bundle under Drivers Code with the driver's name in namespace `rbn`, and reports no error

### Requirement: The tree publishes a Hubitat Package Manager repository index

`hubitat/repository.json` SHALL list every driver's manifest as a package entry with a stable UUID `id`, a `category` and `tags` drawn from HPM's published lists, and a `location` that is the manifest's raw GitHub URL.
`just hubitat check` SHALL exit non-zero when an entry's manifest file does not exist in the tree or when a manifest in the tree is missing from the index.

#### Scenario: Added as a custom repository

- **WHEN** the index's raw URL is added under HPM → Package Manager Settings → Add a custom repository
- **THEN** every package in the index appears in HPM's Install list

#### Scenario: Version bump surfaces as an update

- **WHEN** a driver's `version()` and manifest `version` are raised together, the bundle regenerated, and the commit pushed
- **THEN** HPM's Update check lists that package as having a new version

#### Scenario: Dangling index entry is refused

- **WHEN** `repository.json` names a manifest path that does not exist under `hubitat/drivers/`
- **THEN** `just hubitat check` exits non-zero and names the entry

### Requirement: A minimal VZM31-SN driver covers the standard clusters

The repository SHALL carry `hubitat/drivers/inovelli-vzm31-sn/` with a driver named `Inovelli Dimmer (Blue, VZM31-SN)` in namespace `rbn`, built on `rbn.common`, `rbn.switch`, `rbn.level`, `rbn.meter`, and `rbn.reporting`, declaring the upstream fingerprints for model `VZM31-SN` manufacturer `Inovelli`.
On a paired dimmer it SHALL switch and dim from the hub, reflect physical switching and dimming, report energy in kWh (device value ÷ 100) and power in W (device value ÷ 10), treat cluster `0xFC31` as unknown, and send no Configure Reporting commands unless Configure is explicitly invoked.

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

- **WHEN** the paddle is double-tapped (an Inovelli `0xFC31` command)
- **THEN** the log shows an unknown-cluster warning for `0xFC31`, no `error` line, and no button event

#### Scenario: No reporting changes without Configure

- **WHEN** the device is moved onto the driver, refreshed, switched, and dimmed, and Configure is never pressed
- **THEN** the debug log contains no Configure Reporting command for `0x0702` or `0x0B04`

### Requirement: Validation status names what was verified and where

`hubitat/README.md` SHALL state, per library, whether it has been runtime-verified and on which device and date, or that it is compile-verified only.
A driver SHALL NOT be described as validated for behaviour that was not exercised.

#### Scenario: Status matrix after the dimmer run

- **WHEN** the VZM31-SN validation has completed and no Cube has paired
- **THEN** the README lists `common`, `switch`, `level`, `meter`, `reporting` as runtime-verified on a VZM31-SN with the date, and `xiaomi`, `button`, `battery` as compile-verified only

#### Scenario: Status matrix after a Cube pairs

- **WHEN** the gated Cube scenarios have been run
- **THEN** the README lists `xiaomi`, `button`, and `battery` as runtime-verified on the Cube with the date
