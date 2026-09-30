---
paths:
  - "hubitat/**"
---

# hubitat — Hubitat libraries and drivers (namespace `rbn`)

Groovy for the Hubitat Elevation hub. Libraries are forked from
`kkossev/Hubitat` (see **Provenance**); drivers are authored here against them.
Nothing under this tree is evaluated by Nix or run in CI; the hub compiles a
driver when it is saved, and that save is the only compile check that exists.

## Layout and the source-vs-bundle rule

```
hubitat/
├── libraries/<name>.groovy          # one Hubitat library each, namespace rbn
├── drivers/<driver>/<driver>.groovy          # authored source, #include rbn.<name>
├── drivers/<driver>/<driver>.bundled.groovy  # GENERATED — what the hub imports
├── scripts/bundle.py                # the generator (stdlib Python)
├── bundles/                         # Hubitat "Bundle" zips (HPM etc.), unrelated to *.bundled.groovy
└── apps/, drivers/*.groovy          # third-party code kept verbatim; not on the rbn libraries
```

- Edit `libraries/*.groovy` and `drivers/<d>/<d>.groovy` only. **Never edit a
  `.bundled.groovy`** — run `just hubitat bundle` and commit the result.
  `just hubitat check` exits non-zero naming any stale bundle.
- The bundle is the source with every `#include` line replaced by an empty
  line (driver line numbers are identical in source and bundle), then each
  library between `// ~~~~~ start include rbn.<name> ~~~~~` / `end include`
  markers with every body line suffixed `// library marker rbn.<name>, line N`.
  A hub compile error on a bundle line therefore names the library line.
- Bundles are committed because a driver's `importUrl` is the bundle's raw
  GitHub URL on `main`; the hub imports by URL, no package manager involved.
- Libraries must not `#include` other libraries, and must not contain
  triple-quoted strings (the per-line marker would corrupt them). The bundler
  refuses both.

## Naming

- Files, directories, library names, `just` recipes: lowercase, kebab-case
  only when one word will not do. Library names carry **no `lib` suffix** —
  the directory already says what they are. `hubitat/libraries/common.groovy`
  declares `name: 'common'` and is included as `#include rbn.common`.
- Every library and driver declares `namespace: 'rbn'`.
- **Groovy identifiers stay camelCase.** Hubitat lifecycle methods (`parse`,
  `installed`, `updated`, `configure`, `refresh`, `initialize`), capability
  commands (`on`, `off`, `setLevel`, `push`, `hold`, …), and the dispatcher's
  `customParse<Cluster>Cluster` / `standardParse<Cluster>Cluster` / `custom*`
  hook names are contracts resolved by string, not choices. A renamed hook is
  silently never called.
- Hubitat's documented character set for library `name` includes dashes; it
  has not yet been exercised here (every current name is one word). Verify on
  the hub before committing the first two-word library.

## Dispatch protocol (why a driver stays small)

`common`'s `parse()` calls `standardAndCustomParseCluster()`, which looks up
the cluster in `ClustersMap`, builds `"customParse${Name}Cluster"`, and calls
it via `respondsTo()` if the driver defines it; otherwise it calls
`"standardParse${Name}Cluster"` from whichever library defines it. A driver
therefore implements only the clusters where its device is non-standard.

- **`ClustersMap` is the registry.** A cluster absent from it is logged as
  unknown and never dispatched; a new private cluster (e.g. Inovelli `0xFC31`)
  must be added there, in `common`, before any handler for it can run.
- A driver cannot define `parse()` (duplicate method with the library).
- Lifecycle hooks the libraries resolve the same way: `customRefresh`,
  `customConfigureDevice`, `customInitializeDevice`, `customInitializeVars`,
  `customInitEvents`, `customAqaraBlackMagic`, `customcheckDriverVersion`,
  `customParseDefaultCommandResponse`, and the per-library `*InitializeVars` /
  `*Refresh` handlers named in `initializeVars()` and `refresh()`.

## Emitting Zigbee commands

`sendZigbeeCommands(List<String>)` in `common` is the only emit path: it wraps
the whole list in **one** `HubMultiAction` and one `sendHubCommand`, and counts
it in `state.stats.txCtr`. Never call `sendHubCommand` per command — one
dispatch per attribute is exactly the pattern that made the upstream Inovelli
driver overload the hub. Build the list, return or pass it, send once.

## Platform limits

- A method larger than ~64 KB fails to compile ("Method too large"). Keep
  `switch` blocks small; split parsers by cluster.
- Public attribute, command, and preference names are permanent once a device
  has used them — renaming breaks paired devices and scheduled jobs.

## Provenance and upstream sync

Every forked file keeps its upstream Apache-2.0 header verbatim and carries,
directly under it, `Forked from https://github.com/kkossev/Hubitat (<path>) at
commit <sha>.` plus a `Modified for the rbn namespace:` line. `README.md`
lists them all.

To pull an upstream fix: diff `Libraries/<upstreamName>.groovy` in
`kkossev/Hubitat` between the sha in the provenance line and upstream HEAD,
apply the hunks by hand to `hubitat/libraries/<name>.groovy`, update the sha in
the provenance line and the README row, re-bundle, and re-verify on the hub.
Mapping: `commonLib→common`, `onOffLib→switch`, `xiaomiLib→xiaomi`,
`buttonLib→button`, `batteryLib→battery`, `levelLib→level`,
`energyLib→meter`, `reportingLib→reporting`.

Do not create a `vendor/` directory or keep unmodified upstream copies for
reference; the provenance sha plus the upstream repo is the reference.

## What was stripped from upstream — do not re-add by reflex

The Tuya path is gone from the shared libraries. If a future device speaks
Tuya `0xEF00`, that is a deliberate re-introduction, not a fix.

`common`: `isTuyaE00xCluster()`, `otherTuyaOddities()` and their call in
`parse()`; the `CLUSTER_TUYA` / `SETDATA` / `SETTIME` / `TUYA_*` /
`DP_TYPE_*` getters; `syncTuyaDateTime()`, `standardParseTuyaCluster()`,
`standardProcessTuyaDP()`, `getTuyaAttributeValue()`, `getTuyaCommand()`,
`sendTuyaCommand()`, `getZclSeqNo()`, `getPACKET_ID()`, `tuyaTest()` and its
`_DEBUG` command declaration, `tuyaBlackMagic()`, `queryAllTuyaDP()`,
`isTuya()`, `updateTuyaVersion()`; the `CLUSTER_TUYA` branch in
`parseDefaultCommandResponse()`; the `isTuya()` block in `configure()`; the
`updateTuyaVersion()` calls in `initialize()` and `checkDriverVersion()`; the
`0xEF00: 'Tuya'` entry in `ClustersMap`.
`switch`: the `sendTuyaParameter` branches in `on()` / `off()`.
`battery`: the `isTuya()` branch in the percentage handler,
`tuyaToBatteryLevel()`, `handleTuyaBatteryLevel()`.

Everything Aqara/Xiaomi (`aqaraBlackMagic()`, `updateAqaraVersion()`,
`isAqara()`, all of `xiaomi`) is intentionally kept.

## Verifying on the hub

Hubitat compiles a library only when a driver that includes it is saved, so a
library with no committed driver is unverified. To compile-check all
libraries at once: write an uncommitted probe source containing only a
minimal `metadata { definition(name: 'rbn include-all probe', namespace: 'rbn',
author: 'probe') { capability 'Sensor' } }`, a `DEVICE_TYPE`, and one
`#include rbn.<name>` per library; `just hubitat bundle <path>`; save the
bundle under Drivers Code; delete the driver from the hub and the probe from
disk. Never commit the probe.

Validation status is recorded in `README.md`. Runtime behaviour on a paired
device is a separate change from compile verification; do not claim the
former from the latter.
