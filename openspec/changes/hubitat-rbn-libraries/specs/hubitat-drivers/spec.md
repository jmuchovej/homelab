## Purpose

Defines the contract for Hubitat Groovy code carried in this repository: where shared libraries and device drivers live and how they are named, that all of it belongs to the `rbn` namespace, how a driver's single-file importable bundle is produced from its source and libraries, what a file forked from upstream must retain, and what the shared message-parsing path must not do.

## ADDED Requirements

### Requirement: Hubitat code lives under `hubitat/` with lowercase names

The repository SHALL keep shared Hubitat libraries at `hubitat/libraries/<name>.groovy` and each device driver in its own directory at `hubitat/drivers/<driver>/`, whose authored source is `hubitat/drivers/<driver>/<driver>.groovy`. `<name>` SHALL be a lowercase word naming what the library covers (kebab-case only when one word will not do) and SHALL NOT carry a `lib` suffix; `<driver>` SHALL be kebab-case. The tree SHALL NOT contain a `vendor/` directory or any other copy of upstream code kept for reference.

#### Scenario: Library is found by its name

- **WHEN** a driver source contains `#include rbn.common`
- **THEN** the library it refers to is the file `hubitat/libraries/common.groovy`

#### Scenario: No library suffix

- **WHEN** `hubitat/libraries/` is listed
- **THEN** no filename ends in `lib.groovy` or `-lib.groovy`, and the on/off library is `switch.groovy`

#### Scenario: Driver directory holds source and bundle only

- **WHEN** `hubitat/drivers/aqara-cube-t1-pro/` is listed
- **THEN** it contains `aqara-cube-t1-pro.groovy` and `aqara-cube-t1-pro.bundled.groovy` and no file whose name is not kebab-case apart from the `.bundled.groovy` suffix

#### Scenario: No vendored upstream copies

- **WHEN** the tree under `hubitat/` is searched for a `vendor` directory or for a file declaring `namespace: 'kkossev'`
- **THEN** there are zero matches

### Requirement: Every library and driver is in namespace `rbn`

Every library under `hubitat/libraries/` SHALL declare `namespace: 'rbn'` and a `name:` equal to its filename without the `.groovy` extension. Every driver source under `hubitat/drivers/` SHALL declare `namespace: 'rbn'` and SHALL reference libraries only as `#include rbn.<name>`.

#### Scenario: Library identity matches its file

- **WHEN** `hubitat/libraries/switch.groovy` is read
- **THEN** its `library(...)` block declares `namespace: 'rbn'` and `name: 'switch'`

#### Scenario: Driver includes only rbn libraries

- **WHEN** every `#include` line under `hubitat/drivers/` is collected
- **THEN** each has the form `#include rbn.<name>` and `hubitat/libraries/<name>.groovy` exists for it

#### Scenario: Hub accepts the library identity

- **WHEN** `hubitat/libraries/common.groovy` is saved as a library on the hub and a driver containing `#include rbn.common` is saved
- **THEN** both save without error and the driver's expanded code contains the library body

### Requirement: A driver's importable artifact is a generated bundle

For every driver source `hubitat/drivers/<driver>/<driver>.groovy` the repository SHALL contain `hubitat/drivers/<driver>/<driver>.bundled.groovy`, generated from the source and its included libraries and committed. The bundle SHALL consist of the source with each `#include` line replaced by an empty line, so that every source line keeps its line number, followed by a `Libraries` banner comment and then each included library in include order. Each library SHALL be delimited by `// ~~~~~ start include rbn.<name> ~~~~~` and `// ~~~~~ end include rbn.<name> ~~~~~` lines, and every line of the library body SHALL carry the suffix `// library marker rbn.<name>, line <n>` where `<n>` is that line's 1-based number in the library file. The driver's `importUrl` SHALL point at the bundle's raw URL on this repository's default branch.

#### Scenario: Source line numbers survive bundling

- **WHEN** a driver source has `metadata {` on line 50 and five `#include` lines above it
- **THEN** line 50 of its bundle is `metadata {`

#### Scenario: Compile error maps back to a library line

- **WHEN** the hub reports an error on bundle line `L` and that line ends with `// library marker rbn.common, line 412`
- **THEN** the defect is at line 412 of `hubitat/libraries/common.groovy`

#### Scenario: Bundle drift is detected

- **WHEN** `just hubitat check` runs after a library or driver source has changed and the bundle has not been regenerated
- **THEN** it exits non-zero and names the stale bundle

#### Scenario: Bundle is current

- **WHEN** `just hubitat bundle` has run and `just hubitat check` runs with no further edits
- **THEN** it exits zero

#### Scenario: Import by URL without a package manager

- **WHEN** the driver's `importUrl` is pasted into the hub's Drivers Code import dialog
- **THEN** the hub fetches the bundle and it saves without error

### Requirement: The bundler refuses inputs it cannot bundle faithfully

Bundling SHALL fail with a message naming the offending file when a driver includes a library that does not exist under `hubitat/libraries/`, when an included library itself contains an `#include` line, or when a library contains a triple-quoted string literal (whose interior lines a trailing marker comment would corrupt).

#### Scenario: Missing library

- **WHEN** a driver contains `#include rbn.nosuch`
- **THEN** bundling exits non-zero and the message names `nosuch`

#### Scenario: Nested include

- **WHEN** a file under `hubitat/libraries/` contains a line beginning with `#include`
- **THEN** bundling any driver that includes it exits non-zero and the message names that library

#### Scenario: Triple-quoted string

- **WHEN** a file under `hubitat/libraries/` contains `'''` or `"""`
- **THEN** bundling any driver that includes it exits non-zero and the message names that library

### Requirement: Forked files retain upstream attribution

Every file under `hubitat/libraries/` or `hubitat/drivers/` derived from another repository SHALL keep that file's original copyright and license header unmodified and SHALL carry, immediately after it, a notice naming the source repository, the source path, the commit it was taken from, and that the file has been modified. `hubitat/README.md` SHALL list every such file with the same provenance.

#### Scenario: Forked library carries provenance

- **WHEN** the header of `hubitat/libraries/common.groovy` is read
- **THEN** it contains the upstream Apache-2.0 notice naming Krassimir Kossev and a line naming `kkossev/Hubitat`, `Libraries/commonLib.groovy`, commit `0bf47407`, and that the file is modified

#### Scenario: README enumerates the fork

- **WHEN** `hubitat/README.md` is read
- **THEN** it lists each forked library and driver with its upstream path and commit

### Requirement: The shared parse path performs no Tuya pre-processing

The shared library's message handler SHALL dispatch an incoming Zigbee message by cluster without first attempting Tuya-specific parsing, SHALL treat cluster `0xEF00` as an unknown cluster, and SHALL expose no Tuya command, datapoint, or time-synchronisation surface. Aqara/Xiaomi handling SHALL be unaffected.

#### Scenario: Ordinary cluster report is dispatched directly

- **WHEN** an attribute report for cluster `0x0001` (power configuration) arrives with debug logging enabled
- **THEN** the log shows the message dispatched to the battery handler and contains no line mentioning Tuya

#### Scenario: Tuya cluster is unknown

- **WHEN** a message on cluster `0xEF00` arrives with debug logging enabled
- **THEN** the log reports an unknown cluster and no datapoint processing occurs

#### Scenario: Tuya surface is absent from the fork

- **WHEN** the non-comment lines of `hubitat/libraries/` are searched for `EF00`, `tuyaBlackMagic`, `sendTuyaCommand`, `syncTuyaDateTime`, `isTuya(`, or `tuyaTest`
- **THEN** there are zero matches (the retained upstream version-history comments and the provenance notices may still name them)

#### Scenario: Aqara handling remains

- **WHEN** the Aqara Cube T1 Pro reports on cluster `0xFCC0`
- **THEN** the report is parsed and the corresponding events are emitted as before the fork

### Requirement: Command lists are dispatched as a single hub action

A list of Zigbee commands produced by a library or driver method SHALL be sent to the hub as one dispatch containing every command, not as one dispatch per command.

#### Scenario: Refresh is one dispatch

- **WHEN** `refresh` is invoked on a device using the forked libraries with debug logging enabled
- **THEN** the log contains exactly one `sendZigbeeCommands: sent cmd=` line for that refresh, whose list holds every read command issued

### Requirement: The Aqara Cube T1 Pro driver is ported to the fork

The repository SHALL carry the Aqara Cube T1 Pro driver as `hubitat/drivers/aqara-cube-t1-pro/`, built on the `rbn` libraries, declaring the same fingerprints as upstream (model `lumi.remote.cagl02`, manufacturer `LUMI`) and the same commands, attributes, and hooks, so that a Cube that pairs is offered this driver and behaves as it did on the upstream driver.

#### Scenario: Bundle compiles on the hub

- **WHEN** `aqara-cube-t1-pro.bundled.groovy` is saved under Drivers Code
- **THEN** it saves without error and appears as `Aqara Cube T1 Pro` in namespace `rbn`

#### Scenario: Public surface is unchanged

- **WHEN** the ported source is diffed against upstream `Aqara_Cube_T1_Pro.groovy`
- **THEN** the only differing hunks are the `#include` lines, `namespace`, `importUrl`, the provenance block, and the version-history/timestamp lines; every `capability`, `attribute`, `command`, `fingerprint`, and `custom*` method is identical

#### Scenario: Paired Cube produces the same events

- **WHEN** a Cube paired to the `rbn` driver is flipped, shaken, rotated left, and rotated right
- **THEN** it emits `pushed`, `doubleTapped`, `held`, and `released` button events respectively, with `cubeSide`, `angle`, and `sideUp` updated as before

### Requirement: The Hubitat tree has a scoped agent rule

`hubitat/AGENTS.md` SHALL exist with `paths:` frontmatter matching `hubitat/**` and SHALL be reachable at `.agents/rules/hubitat.md` as a relative symlink, following the repository's rule-linking convention.

#### Scenario: Rule applies to Hubitat files

- **WHEN** a file under `hubitat/` is edited in an agent session
- **THEN** the rule at `.agents/rules/hubitat.md` resolves to `hubitat/AGENTS.md` and its glob matches the file

#### Scenario: Rule does not load elsewhere

- **WHEN** a file under `modules/` is edited
- **THEN** the `hubitat/**` glob does not match it
