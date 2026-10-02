# hubitat-drivers Specification

## Purpose

Defines the contract for Hubitat Groovy code carried in this repository: where shared libraries and device drivers live and how they are named, that all of it belongs to the `rbn` namespace, how a driver's single-file importable bundle is produced from its source and libraries, what a file forked from upstream must retain, and what the shared message-parsing path must not do.

## Requirements

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

### Requirement: `hubitat/` is a self-contained uv workspace member and an importable package

`hubitat/` SHALL be a uv workspace member with its own `pyproject.toml` declaring its dependencies and no build system, listed in the root `pyproject.toml`'s `[tool.uv.workspace]`, sharing the root lockfile. The directory itself SHALL be the importable package (`hubitat/__init__.py`, `hubitat/__main__.py`), with its command-line entry point `python -m hubitat`, run from the repository root as `uv run --package hubitat -m hubitat <command>`. It SHALL NOT import from `src/homelab/` and `src/homelab/` SHALL NOT import from it, and the root `pyproject.toml` SHALL change only by the workspace stanza. Data directories under `hubitat/` (`libraries/`, `drivers/`, `bundles/`, `apps/`) SHALL be located relative to the package file, not the working directory.

#### Scenario: Module runs from the repo root

- **WHEN** `uv run --package hubitat -m hubitat --help` is run at the repository root
- **THEN** it exits zero and lists `bundle`, `check`, `push`, `probe`, and `bump`

#### Scenario: Member is virtual and shares the lock

- **WHEN** `hubitat/pyproject.toml` and the root `pyproject.toml` are read after `uv lock`
- **THEN** the member has no `[build-system]`, the root names it under `[tool.uv.workspace].members`, there is exactly one `uv.lock` in the repository, and the root's `[project]` and `[dependency-groups]` are unchanged

#### Scenario: No coupling to the homelab CLI

- **WHEN** `rg -n 'from homelab|import homelab' hubitat/` and `rg -n 'hubitat' src/homelab/` are run
- **THEN** both are empty

#### Scenario: Works from another directory

- **WHEN** `uv run --directory <repo> --package hubitat -m hubitat check` is run from outside the repository
- **THEN** it finds `hubitat/drivers/` and `hubitat/libraries/` and exits with the same result as when run from the root

### Requirement: `bundle` and `check` keep the bundler contract

`bundle [SOURCE…]` SHALL produce the same bundles the previous script did (include lines blanked, single `Libraries` banner, per-library markers), and `check` SHALL exit non-zero naming every stale bundle. When a `packageManifest.json` exists beside a driver source, `check` SHALL additionally validate it per the manifest requirements and name the file on failure. `hubitat/scripts/` SHALL no longer exist.

#### Scenario: Bundle output is unchanged by the move

- **WHEN** `bundle` is run on the Aqara Cube T1 Pro source
- **THEN** the resulting `aqara-cube-t1-pro.bundled.groovy` is byte-identical to the one committed by `hubitat-rbn-libraries`

#### Scenario: Script location is gone

- **WHEN** `hubitat/` is listed
- **THEN** there is no `scripts/` directory and `bundle.py` is a module of the package

### Requirement: `push` installs or updates drivers on the hub idempotently

`push [DRIVER…] [--dry-run]` SHALL, for each selected driver (default: all), read the hub's list of user drivers, match by name and namespace `rbn`, and either create the driver from its bundle when absent or update it when present. Before updating it SHALL fetch the hub's current source and SHALL skip the driver, reporting "unchanged", when that source equals the bundle. `--dry-run` SHALL report what would happen and send no writes. It SHALL log in first when the hub reports security enabled, SHALL fail with a clear message when `HUBITAT_URL` is unset or the hub is unreachable, and SHALL never write anything outside namespace `rbn`.

#### Scenario: First push creates

- **WHEN** no driver named `Aqara Cube T1 Pro` exists in namespace `rbn` on the hub and `push aqara-cube-t1-pro` runs
- **THEN** the hub's Drivers Code gains it, with source equal to the committed bundle, and the command reports "created"

#### Scenario: Re-push is a no-op

- **WHEN** `push` runs again with no change to the bundle
- **THEN** no write request is sent and the command reports "unchanged"

#### Scenario: Changed bundle updates in place

- **WHEN** a library is edited, `bundle` is run, and `push` runs
- **THEN** the hub driver keeps its code id and its source equals the new bundle, and the command reports "updated"

#### Scenario: Dry run writes nothing

- **WHEN** `push --dry-run` runs with one stale driver
- **THEN** it reports that driver as "would update" and the hub's source is unchanged afterwards

#### Scenario: Missing hub address

- **WHEN** `push` runs without `HUBITAT_URL` in the environment
- **THEN** it exits non-zero with a message naming `HUBITAT_URL` and `secretspec`, and no network request is made

### Requirement: `probe` compile-checks every library on the hub

`probe` SHALL generate, in a temporary location, a driver source that includes every library under `hubitat/libraries/`, bundle it, push it to the hub as `rbn include-all probe`, report success or the hub's compile error with the library line resolved through the bundle's marker, and delete the probe driver from the hub whether or not compilation succeeded. It SHALL leave no file in the repository.

#### Scenario: All libraries compile

- **WHEN** `probe` runs against a hub where every library compiles
- **THEN** it reports success, and afterwards the hub has no driver named `rbn include-all probe`

#### Scenario: A library fails to compile

- **WHEN** a syntax error is introduced into `hubitat/libraries/button.groovy` and `probe` runs
- **THEN** it exits non-zero naming `button.groovy` and the offending line number, and the probe driver is still removed from the hub

### Requirement: `bump` changes a driver's version in every place that must agree

`bump DRIVER VERSION` SHALL rewrite the driver source's `version()` string and `timeStamp()`, rewrite `version` and `dateReleased` in a sibling `packageManifest.json` when one exists, and regenerate the bundle, so that `check` passes immediately afterwards.

#### Scenario: Bump keeps check green

- **WHEN** `bump aqara-cube-t1-pro 3.3.1` runs
- **THEN** `version()` reads `3.3.1`, the manifest (if present) reads `3.3.1` with today's `dateReleased`, the bundle is regenerated, and `check` exits zero

### Requirement: Hub access is configured through secretspec

A root `secretspec.toml` SHALL declare `HUBITAT_URL` as required and `HUBITAT_USERNAME` and `HUBITAT_PASSWORD` as optional. Commands that contact the hub SHALL read only these variables, SHALL use the credentials only when the hub reports security enabled, and SHALL never print them.

#### Scenario: secretspec explains what is missing

- **WHEN** `secretspec check --explain` is run before any secret is configured
- **THEN** it lists `HUBITAT_URL` as missing and the two credentials as optional

#### Scenario: Credentials are not logged

- **WHEN** `push` runs with verbose output against a secured hub
- **THEN** the output contains the hub URL and request paths but never the username or password

### Requirement: The package has tests for everything that does not need a hub

`hubitat/tests/` SHALL contain pytest tests covering bundling (line preservation, banner once, markers, the three refusal cases), manifest validation (agreement, version drift, wrong location, wrong identity, non-UUID id, dangling index entry), and `bump`. They SHALL run with `uv run --package hubitat python -m pytest hubitat/tests` from the repository root and SHALL NOT contact a hub.

#### Scenario: Tests pass offline

- **WHEN** `uv run --package hubitat python -m pytest hubitat/tests` runs with no network
- **THEN** every test passes
