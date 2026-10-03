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
├── drivers/<driver>/<driver>.bundled.groovy  # GENERATED — the distribution form (importUrl / HPM)
├── drivers/<driver>/packageManifest.json     # HPM manifest (when the driver is packaged)
├── bundles/                         # Hubitat "Bundle" zips (HPM etc.), unrelated to *.bundled.groovy
└── apps/, drivers/*.groovy          # third-party code kept verbatim; not on the rbn libraries
```

- Edit `libraries/*.groovy` and `drivers/<d>/<d>.groovy` only.
  **Never edit a `.bundled.groovy`** — run `just hubitat bundle` and commit the result.
  `just hubitat check` exits non-zero naming any stale bundle or any manifest that disagrees with its driver.
- **Our hubs run the sources.** Hubitat stores a driver's `#include` lines verbatim and resolves them against its Libraries Code at compile time, so `push` sends the driver source after the libraries it includes.
  The bundle exists for hubs that are not ours: the Import button and HPM fetch one file and cannot install libraries.
- The bundle is the driver source with every `#include` line replaced by a one-line comment naming the bundle line of that library's start marker (driver line numbers are identical in source and bundle), then each library between `// ~~~~~ start include rbn.<name> ~~~~~` / `end include` markers **reduced to its code**: comment-only lines dropped, trailing comments removed, every kept line suffixed `// rbn.<name>#L<n>` with its source line.
  The one comment kept per library is its header block (licence and attribution notice, retained as Apache-2.0 requires), with the changelog collapsed to a `Changelog:` link into the source on `main`.
  A hub compile error on a bundle line therefore names the library line; `probe` does that mapping for you.
  The comment stripper (`strip_comments`) is a three-state line scanner, not a parser; it relies on the libraries having no slashy strings or regex literals (`/…/`), which is true today — `rg '=~|~/' libraries/` before adding one.
- Bundles are committed because a driver's `importUrl` (and its HPM manifest `location`) is the bundle's raw GitHub URL on `main`.
  Nothing of ours compiles a bundle except `probe`, so run it after any bundler change.
- Libraries must not `#include` other libraries, and must not contain triple-quoted strings (the per-line marker would corrupt them).
  The bundler refuses both.
- **Groovy is formatted** by `npm-groovy-lint --format` through `treefmt` (`.config/groovylintrc.yaml` is its rule set), libraries and forked drivers included; only `*.bundled.groovy` is excluded, because it is regenerated from the formatted sources.
  After a format pass that touches a library or a driver source, run `just hubitat bundle` and commit the bundle with it, or `check` fails.
  CodeNarc cannot parse `#include` lines, so a driver source always carries one `NglParseError` in lint output; it is noise, and `--failon none` keeps it from failing the formatter.
  The formatter has one known-bad fixer (`SpaceAroundOperator`, which once rewrote `!=` as `! =`); it is disabled in the rc file — do not re-enable it without re-running `probe`.

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
- `treefmt` runs `ruff-check`/`ruff-format` on every `.py` here with the repo's configuration; nothing to configure in this directory.

## Reaching the hub: `push` and `probe`

Hub access is configured only through `secretspec` (declared in the root `secretspec.toml`): `HUBITAT_URL` (required) and `HUBITAT_USERNAME`/`HUBITAT_PASSWORD` (optional, used only when the hub reports security enabled — detected per run, never assumed).
`just hubitat push` / `probe` wrap the command in `secretspec run`; the tool refuses to start without the URL and never prints credentials.
The driver endpoints are the ones the Hubitat Package Manager uses (`/hub2/userDeviceTypes`, `/driver/ajax/code`, `/driver/save`, `/driver/ajax/update`, `/driver/editor/deleteJson/<id>`); its Groovy source is their only documentation.
There is no API key for these admin endpoints: the hub's Maker API tokens cover device commands only, so with hub security enabled the only option is the login form, which is what `hub.py` does.

- `push [DRIVER…] [--dry-run]` first plans the libraries those drivers include (Libraries Code, same rules), then the drivers, each resolved by `(name, namespace)` from the hub's user code list, **namespace `rbn` only** — a same-named driver in `kkossev` or `InovelliUSA` is never touched.
  Absent → create from the source; present → read the hub's source and `version`, skip as `unchanged` when equal, otherwise update with that just-read `version`.
  Re-running is therefore a no-op; `--dry-run` performs the reads and prints the decision.
  The hub compiles the driver on save against the libraries just pushed, so a library change followed by `push` is also its compile check.
- `probe` compiles the **bundled** form: it generates an include-all driver (`rbn include-all probe`) in a temp directory, bundles it through the real bundler, pushes that bundle, and deletes it in a `finally` — by the ids it touched, then by name for any earlier run's leftovers.
  A compile error is printed with the hub's text and the `<library>.groovy:<line>` it resolves to through the `#L` markers.
  Nothing is written to the repo.
- `push --libraries [NAME…]` pushes only libraries, against `/hub2/userLibraries`, `/library/ajax/code`, `/library/save`, `/library/ajax/update`, `/library/edit/deleteJson/<id>` (confirmed on firmware 2.4.3.177; note `edit/`, not `editor/`, for delete).
- `push` moves code, not devices: pairing, driver assignment, and Configure stay on the hub.

## HPM manifests

**Every driver directory has a `packageManifest.json`** and `repository.json` at `hubitat/` lists every one of them; both are hand-written and `just hubitat check` refuses the tree otherwise (`manifest.py`): a driver without a manifest, a manifest `version` that differs from the driver's `version()`, anything but exactly one `drivers[]` entry, a namespace other than `rbn`, a `name` that differs from the `definition(name: …)`, a `location` not ending in `/hubitat/drivers/<d>/<d>.bundled.groovy`, a non-UUID id, an index entry whose manifest does not exist, a manifest missing from the index, or an index entry without `category`/`tags`.
HPM installs the bundle at `location` and nothing else — it has no notion of libraries — and its update detection is the manifest `version` string alone, so a release is `just hubitat bump <driver> <version>` (source, manifest, bundle in one step), never a hand edit of one of the three.
Ids (`drivers[].id` and `packages[].id`) are minted once with `uuidgen` and never change; HPM keys installed packages on them.
Code that reached the hub by `push` or Import is unknown to HPM until its Match Up adopts it by name and namespace.

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

## Inovelli VZM31-SN: parameters and units

`0xFC31` is Inovelli's private cluster; `ClustersMap` routes it to the driver's `customParseInovelliPrivateCluster()` (the one `rbn` addition to `common`'s map).
Attribute reports on it are parameters (attribute id == parameter number); cluster-specific commands on it are scene buttons and LED events and are logged at debug and dropped until a driver implements them.

- **The device is the source of truth for parameters.**
  `refresh` reads every row of the driver's `Parameters` table into `settings.parameter<N>` and `state.parameters`; `customUpdated()` writes only parameters whose preference differs from the last value the device reported, then reads them back; there is no `customConfigureDevice()`, so `configure` writes nothing on `0xFC31`.
  A parameter that was never read is never written (it is warned about instead) — do not "fix" that by writing table defaults; a working unit's smart-bulb mode and bindings would be reset.
- `device.updateSetting()` only updates a settings row that already exists, and the hub creates rows for a driver's inputs on the first Save Preferences after the driver is selected; until then the driver's writes are silently dropped (verified 2026-10-03: `settings.parameterN` read back `null` immediately after the call, then held the value once the user had saved).
  Hence the README's "Save Preferences once, then refresh" step.
  `/device/fullJson/<id>` does not reflect driver-written settings either; the page does, after a reload.
- The table is keyed by parameter number and generated (rate options from one method), carries only the parameters that are verified, and keeps Inovelli's `parameter<N>` setting names so a device moved between drivers shows the same stored preferences.
- `@Field static` initialisers in a Hubitat script cannot reference other `@Field` constants — shared option maps are static methods (`rateOptions()`, `ledColors()`), which the hub compiles.
- **Units are group bindings**: `bindGroup <id>` binds endpoint 2 to a Zigbee group for `0x0006`/`0x0008`, `unbindGroup <id>` removes them, `readBindings` requests the ZDO binding table (`0x0033`) and `customParseZdoClusters()` parses the `0x8033` reply into the `bindings` attribute, paging by start index.
  Bulb membership comes from Hubitat's Groups and Scenes app with Zigbee group messaging on; its Zigbee group id is the `n` in the group device's DNI `Group_<n>` (verified on the hub with a Get Group Membership query).
  The device acknowledges bind/unbind within a second; the commands wait 3 s and then read the table back, which is the proof — not the acknowledgement.
- Before diagnosing a unit, read the facts: `bindings` (switch half), the Hubitat group's Zigbee messaging toggle (bulb half), `state.parameters` and the `powerSource`/`internalTemp`/`overHeat` attributes.
- Raw commands relayed through `bind(<string>)` reach this device; the same relay addressed at another device's DNI did not produce replies on the hub — do not use one device's relay to talk to another.

## Platform limits

- A method larger than ~64 KB fails to compile ("Method too large").
  Keep `switch` blocks small; split parsers by cluster.
- Public attribute, command, and preference names are permanent once a device has used them — renaming breaks paired devices and scheduled jobs.
- Every driver source carries single-line `static String version() { "…" }` and `static String timeStamp() {"…"}` lines and one `definition(` call; `manifest.py` parses identity from them and `bump` rewrites them, both refusing anything else.

## Provenance and upstream sync

Every forked file keeps its upstream Apache-2.0 header verbatim and carries, directly under it, `Forked from https://github.com/kkossev/Hubitat (<path>) at commit <sha>.` plus a `Modified for the rbn namespace:` line.
`README.md` lists them all.

To pull an upstream fix: diff `Libraries/<upstreamName>.groovy` in `kkossev/Hubitat` between the sha in the provenance line and upstream HEAD — upstream against upstream, so the diff is unaffected by the formatting applied here — apply the hunks by hand to `hubitat/libraries/<name>.groovy`, let `nix fmt` reformat the result, update the sha in the provenance line and the README row, re-bundle, `probe`, and re-verify on a device.
Never diff the local file against upstream directly; the formatter's changes drown the real ones.
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

Hubitat compiles a library only when a driver that includes it is saved, so `just hubitat push` is the compile check for each driver and its libraries as sourced, and `just hubitat probe` for the whole library set as bundled.
Validation status is recorded in `README.md`.
Runtime behaviour on a paired device is a separate change from compile verification; do not claim the former from the latter.
