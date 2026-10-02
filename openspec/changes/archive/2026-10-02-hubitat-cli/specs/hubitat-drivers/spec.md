## ADDED Requirements

### Requirement: `hubitat/` is a self-contained uv workspace member and an importable package

`hubitat/` SHALL be a uv workspace member with its own `pyproject.toml` declaring its dependencies and no build system, listed in the root `pyproject.toml`'s `[tool.uv.workspace]`, sharing the root lockfile.
The directory itself SHALL be the importable package (`hubitat/__init__.py`, `hubitat/__main__.py`), with its command-line entry point `python -m hubitat`, run from the repository root as `uv run --package hubitat -m hubitat <command>`.
It SHALL NOT import from `src/homelab/` and `src/homelab/` SHALL NOT import from it, and the root `pyproject.toml` SHALL change only by the workspace stanza.
Data directories under `hubitat/` (`libraries/`, `drivers/`, `bundles/`, `apps/`) SHALL be located relative to the package file, not the working directory.

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

`bundle [SOURCE…]` SHALL produce the same bundles the previous script did (include lines blanked, single `Libraries` banner, per-library markers), and `check` SHALL exit non-zero naming every stale bundle.
When a `packageManifest.json` exists beside a driver source, `check` SHALL additionally validate it per the manifest requirements and name the file on failure.
`hubitat/scripts/` SHALL no longer exist.

#### Scenario: Bundle output is unchanged by the move

- **WHEN** `bundle` is run on the Aqara Cube T1 Pro source
- **THEN** the resulting `aqara-cube-t1-pro.bundled.groovy` is byte-identical to the one committed by `hubitat-rbn-libraries`

#### Scenario: Script location is gone

- **WHEN** `hubitat/` is listed
- **THEN** there is no `scripts/` directory and `bundle.py` is a module of the package

### Requirement: `push` installs or updates drivers on the hub idempotently

`push [DRIVER…] [--dry-run]` SHALL, for each selected driver (default: all), read the hub's list of user drivers, match by name and namespace `rbn`, and either create the driver from its bundle when absent or update it when present.
Before updating it SHALL fetch the hub's current source and SHALL skip the driver, reporting "unchanged", when that source equals the bundle.
`--dry-run` SHALL report what would happen and send no writes.
It SHALL log in first when the hub reports security enabled, SHALL fail with a clear message when `HUBITAT_URL` is unset or the hub is unreachable, and SHALL never write anything outside namespace `rbn`.

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

`probe` SHALL generate, in a temporary location, a driver source that includes every library under `hubitat/libraries/`, bundle it, push it to the hub as `rbn include-all probe`, report success or the hub's compile error with the library line resolved through the bundle's marker, and delete the probe driver from the hub whether or not compilation succeeded.
It SHALL leave no file in the repository.

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

A root `secretspec.toml` SHALL declare `HUBITAT_URL` as required and `HUBITAT_USERNAME` and `HUBITAT_PASSWORD` as optional.
Commands that contact the hub SHALL read only these variables, SHALL use the credentials only when the hub reports security enabled, and SHALL never print them.

#### Scenario: secretspec explains what is missing

- **WHEN** `secretspec check --explain` is run before any secret is configured
- **THEN** it lists `HUBITAT_URL` as missing and the two credentials as optional

#### Scenario: Credentials are not logged

- **WHEN** `push` runs with verbose output against a secured hub
- **THEN** the output contains the hub URL and request paths but never the username or password

### Requirement: The package has tests for everything that does not need a hub

`hubitat/tests/` SHALL contain pytest tests covering bundling (line preservation, banner once, markers, the three refusal cases), manifest validation (agreement, version drift, wrong location, wrong identity, non-UUID id, dangling index entry), and `bump`.
They SHALL run with `uv run --package hubitat python -m pytest hubitat/tests` from the repository root and SHALL NOT contact a hub.

#### Scenario: Tests pass offline

- **WHEN** `uv run --package hubitat python -m pytest hubitat/tests` runs with no network
- **THEN** every test passes
