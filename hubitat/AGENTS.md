---
paths:
  - "hubitat/**"
---

# hubitat — Hubitat libraries and drivers (namespace `rbn`)

Groovy for the Hubitat Elevation hub, plus the Python package that moves it there.
Libraries are forked from `kkossev/Hubitat` (see **Provenance**); drivers are authored here against them.
Nothing under this tree is evaluated by Nix or run in CI; the hub compiles a driver when it is saved, and that save is the only compile check that exists — `probe` and `push` are how that save happens from the repo.

## Layout and the source-vs-bundle rule

```
hubitat/
├── pyproject.toml, __init__.py, __main__.py   # uv workspace member; the directory IS the package
├── cli.py, bundle.py, manifest.py, hub.py, push.py, bump.py
├── tests/                           # pytest, offline (hub traffic goes through httpx.MockTransport)
├── justfile                         # thin recipes over `uv run --package hubitat -m hubitat`
├── libraries/<name>.groovy          # one Hubitat library each, namespace rbn
├── drivers/<driver>/<driver>.groovy          # authored source, #include rbn.<name>
├── drivers/<driver>/<driver>.bundled.groovy  # GENERATED — what the hub imports
├── drivers/<driver>/packageManifest.json     # HPM manifest (when the driver is packaged)
├── bundles/                         # Hubitat "Bundle" zips (HPM etc.), unrelated to *.bundled.groovy
└── apps/, drivers/*.groovy          # third-party code kept verbatim; not on the rbn libraries
```

- Edit `libraries/*.groovy` and `drivers/<d>/<d>.groovy` only.
  **Never edit a `.bundled.groovy`** — run `just hubitat bundle` and commit the result.
  `just hubitat check` exits non-zero naming any stale bundle or any manifest that disagrees with its driver.
- The bundle is the source with every `#include` line replaced by an empty line (driver line numbers are identical in source and bundle), then each library between `// ~~~~~ start include rbn.<name> ~~~~~` / `end include` markers with every body line suffixed `// library marker rbn.<name>, line N`.
  A hub compile error on a bundle line therefore names the library line; `probe` and `push` do that mapping for you.
- Bundles are committed because a driver's `importUrl` (and its HPM manifest `location`) is the bundle's raw GitHub URL on `main`.
- Libraries must not `#include` other libraries, and must not contain triple-quoted strings (the per-line marker would corrupt them).
  The bundler refuses both.

## The Python package

`hubitat/` is a uv workspace member **without a build system** (`uv init --bare`): uv resolves and syncs its dependencies but never builds or installs it, which is what lets this directory be the package instead of `src/hubitat/`.
It is found via the working directory, so every invocation runs at the repo root:

```sh
uv run --package hubitat -m hubitat <bundle|check|push|probe|bump> …   # at the root
uv run --directory <repo> --package hubitat -m hubitat …                # from anywhere
uv run --package hubitat python -m pytest hubitat/tests                 # tests
```

The `just hubitat …` recipes are exactly these commands and carry no logic.

- Dependencies live in `hubitat/pyproject.toml` (`httpx`, `typer`, `pydantic`; `pytest` in its `dev` group).
  The root `pyproject.toml` names the member under `[tool.uv.workspace]` and nothing else; one `uv.lock` covers both.
- **No coupling with `src/homelab/`** in either direction — no imports, no shared types, no entry in the root's `[project.scripts]` or dependency groups.
- `cli.py` stays thin: it parses arguments, calls a module, prints, exits.
  Logic lives in `bundle.py`, `manifest.py`, `hub.py`, `push.py`, `bump.py`, and every piece that does not need a hub has a test.
- Modules locate data through `hubitat.ROOT` / `LIBRARIES` / `DRIVERS`, read at call time (not imported as names) so the `tree` fixture can point them at a miniature tree.
- `treefmt` runs `ruff-check`/`ruff-format` on every `.py` here with the repo's defaults; nothing to configure.

## Reaching the hub: `push` and `probe`

Hub access is configured only through `secretspec` (declared in the root `secretspec.toml`): `HUBITAT_URL` (required) and `HUBITAT_USERNAME`/`HUBITAT_PASSWORD` (optional, used only when the hub reports security enabled — detected per run, never assumed).
`just hubitat push` / `probe` wrap the command in `secretspec run`; the tool refuses to start without the URL and never prints credentials.
The endpoints are the ones the Hubitat Package Manager uses (`/hub2/userDeviceTypes`, `/driver/ajax/code`, `/driver/save`, `/driver/ajax/update`, `/driver/editor/deleteJson/<id>`); its Groovy source is their only documentation.

- `push [DRIVER…] [--dry-run]` resolves each driver by `(name, namespace)` from the hub's user driver list, **namespace `rbn` only** — a same-named driver in `kkossev` or `InovelliUSA` is never touched.
  Absent → create from the committed bundle; present → read the hub's source and `version`, skip as `unchanged` when the source equals the bundle, otherwise update with that just-read `version`.
  Re-running is therefore a no-op; `--dry-run` performs the reads and prints the decision.
  A stale bundle is refused — run `bundle` first (`check` tells you).
- `probe` is the compile check for libraries that have no committed driver yet: it generates an include-all driver (`rbn include-all probe`) in a temp directory, bundles it through the real bundler, pushes it, and deletes it in a `finally` — by the ids it touched, then by name for any earlier run's leftovers.
  A compile error is printed with the hub's text and the `<library>.groovy:<line>` it resolves to.
  Nothing is written to the repo.
- Libraries Code is **not** pushed: HPM never installs libraries, so their endpoints are unconfirmed.
  Libraries reach the hub inside bundles; a hand-saved library on the hub is a development convenience, not a deliverable.
- `push` moves code, not devices: pairing, driver assignment, and Configure stay on the hub.

## HPM manifests

`packageManifest.json` beside a driver and `repository.json` at `hubitat/` are hand-written; `check` validates them (`manifest.py`): manifest `version` equals the driver's `version()`, exactly one `drivers[]` entry, namespace `rbn`, `name` equals the `definition(name: …)`, `location` ends in `/hubitat/drivers/<d>/<d>.bundled.groovy`, ids are UUIDs, every index entry's manifest exists and every manifest is indexed.
HPM's update detection is the manifest `version` string alone, so a release is `just hubitat bump <driver> <version>` (source, manifest, bundle in one step) — never a hand edit of one of the three.
Ids are minted once and never change.

## Naming

- Files, directories, library names, `just` recipes: lowercase, kebab-case only when one word will not do.
  Library names carry **no `lib` suffix** — the directory already says what they are.
  `hubitat/libraries/common.groovy` declares `name: 'common'` and is included as `#include rbn.common`.
- Every library and driver declares `namespace: 'rbn'`.
- **Groovy identifiers stay camelCase.**
  Hubitat lifecycle methods (`parse`, `installed`, `updated`, `configure`, `refresh`, `initialize`), capability commands (`on`, `off`, `setLevel`, `push`, `hold`, …), and the dispatcher's `customParse<Cluster>Cluster` / `standardParse<Cluster>Cluster` / `custom*` hook names are contracts resolved by string, not choices.
  A renamed hook is silently never called.
- Hubitat's documented character set for library `name` includes dashes; it has not yet been exercised here (every current name is one word).
  Verify on the hub before committing the first two-word library.
- Python follows ruff defaults; module names are the verb or noun of what they do (`bundle`, `push`), and the CLI imports them as `bundling`, `pushing` to keep the command names free.

## Dispatch protocol (why a driver stays small)

`common`'s `parse()` calls `standardAndCustomParseCluster()`, which looks up the cluster in `ClustersMap`, builds `"customParse${Name}Cluster"`, and calls it via `respondsTo()` if the driver defines it; otherwise it calls `"standardParse${Name}Cluster"` from whichever library defines it.
A driver therefore implements only the clusters where its device is non-standard.

- **`ClustersMap` is the registry.**
  A cluster absent from it is logged as unknown and never dispatched; a new private cluster (e.g. Inovelli `0xFC31`) must be added there, in `common`, before any handler for it can run.
- A driver cannot define `parse()` (duplicate method with the library).
- Lifecycle hooks the libraries resolve the same way: `customRefresh`, `customConfigureDevice`, `customInitializeDevice`, `customInitializeVars`, `customInitEvents`, `customAqaraBlackMagic`, `customcheckDriverVersion`, `customParseDefaultCommandResponse`, and the per-library `*InitializeVars` / `*Refresh` handlers named in `initializeVars()` and `refresh()`.

## Emitting Zigbee commands

`sendZigbeeCommands(List<String>)` in `common` is the only emit path: it wraps the whole list in **one** `HubMultiAction` and one `sendHubCommand`, and counts it in `state.stats.txCtr`.
Never call `sendHubCommand` per command — one dispatch per attribute is exactly the pattern that made the upstream Inovelli driver overload the hub.
Build the list, return or pass it, send once.

## Platform limits

- A method larger than ~64 KB fails to compile ("Method too large").
  Keep `switch` blocks small; split parsers by cluster.
- Public attribute, command, and preference names are permanent once a device has used them — renaming breaks paired devices and scheduled jobs.
- Every driver source carries single-line `static String version() { "…" }` and `static String timeStamp() {"…"}` lines and one `definition(` call; `manifest.py` parses identity from them and `bump` rewrites them, both refusing anything else.

## Provenance and upstream sync

Every forked file keeps its upstream Apache-2.0 header verbatim and carries, directly under it, `Forked from https://github.com/kkossev/Hubitat (<path>) at commit <sha>.` plus a `Modified for the rbn namespace:` line.
`README.md` lists them all.

To pull an upstream fix: diff `Libraries/<upstreamName>.groovy` in `kkossev/Hubitat` between the sha in the provenance line and upstream HEAD, apply the hunks by hand to `hubitat/libraries/<name>.groovy`, update the sha in the provenance line and the README row, re-bundle, `probe`, and re-verify on a device.
Mapping: `commonLib→common`, `onOffLib→switch`, `xiaomiLib→xiaomi`, `buttonLib→button`, `batteryLib→battery`, `levelLib→level`, `energyLib→meter`, `reportingLib→reporting`.

Do not create a `vendor/` directory or keep unmodified upstream copies for reference; the provenance sha plus the upstream repo is the reference.

## What was stripped from upstream — do not re-add by reflex

The Tuya path is gone from the shared libraries.
If a future device speaks Tuya `0xEF00`, that is a deliberate re-introduction, not a fix.

`common`: `isTuyaE00xCluster()`, `otherTuyaOddities()` and their call in `parse()`; the `CLUSTER_TUYA` / `SETDATA` / `SETTIME` / `TUYA_*` / `DP_TYPE_*` getters; `syncTuyaDateTime()`, `standardParseTuyaCluster()`, `standardProcessTuyaDP()`, `getTuyaAttributeValue()`, `getTuyaCommand()`, `sendTuyaCommand()`, `getZclSeqNo()`, `getPACKET_ID()`, `tuyaTest()` and its `_DEBUG` command declaration, `tuyaBlackMagic()`, `queryAllTuyaDP()`, `isTuya()`, `updateTuyaVersion()`; the `CLUSTER_TUYA` branch in `parseDefaultCommandResponse()`; the `isTuya()` block in `configure()`; the `updateTuyaVersion()` calls in `initialize()` and `checkDriverVersion()`; the `0xEF00: 'Tuya'` entry in `ClustersMap`.
`switch`: the `sendTuyaParameter` branches in `on()` / `off()`.
`battery`: the `isTuya()` branch in the percentage handler, `tuyaToBatteryLevel()`, `handleTuyaBatteryLevel()`.

Everything Aqara/Xiaomi (`aqaraBlackMagic()`, `updateAqaraVersion()`, `isAqara()`, all of `xiaomi`) is intentionally kept.

## Verifying on the hub

Hubitat compiles a library only when a driver that includes it is saved, so `just hubitat probe` is the compile check for the whole library set and `just hubitat push` for each driver.
Validation status is recorded in `README.md`.
Runtime behaviour on a paired device is a separate change from compile verification; do not claim the former from the latter.
