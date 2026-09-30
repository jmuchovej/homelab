# hubitat

Groovy libraries and device drivers for the Hubitat Elevation hub, all in the
`rbn` namespace. The libraries are a fork of Krassimir Kossev's
[`kkossev/Hubitat`](https://github.com/kkossev/Hubitat) with the Tuya code path
removed; drivers are authored here against them.

## How a driver reaches the hub

A driver's source (`drivers/<driver>/<driver>.groovy`) uses
`#include rbn.<name>` lines. Hubitat imports a single file, so the source is
expanded into `drivers/<driver>/<driver>.bundled.groovy` with each library
inlined. **The bundle is generated and committed; never edit it by hand.**

```sh
just hubitat bundle   # regenerate every *.bundled.groovy
just hubitat check    # exit non-zero naming any bundle that is stale
```

Each driver's `importUrl` is the bundle's raw GitHub URL on `main`, so the hub
can import it from Drivers Code → Import without a package manager. That URL
is only valid once the commit is pushed; until then, paste the bundle's
contents into Drivers Code by hand.

`bundles/` holds Hubitat _Bundle_ zips (for example the Hubitat Package
Manager installer) and is unrelated to the generated `*.bundled.groovy` files.

## Validation status

**Compile-verified only.** The `rbn` libraries and the Aqara Cube T1 Pro
driver have been saved on the hub and compile; no device has been run on them
yet. Runtime validation on a paired device is tracked as a separate OpenSpec
change. Do not read "compiles" as "works".

## Attribution

The files below are derived from
[`kkossev/Hubitat`](https://github.com/kkossev/Hubitat), © Krassimir Kossev,
licensed under the Apache License, Version 2.0. Each file keeps its original
license header and states, directly beneath it, that it has been modified and
from which upstream path and commit. Per Apache-2.0 §4 those in-file notices
are the authoritative record; this table is a summary.

| File                                                 | Upstream path                                        | Commit     | Modified                                                   |
| ---------------------------------------------------- | ---------------------------------------------------- | ---------- | ---------------------------------------------------------- |
| `libraries/common.groovy`                            | `Libraries/commonLib.groovy`                         | `0bf47407` | yes — Tuya path removed; identity                          |
| `libraries/switch.groovy`                            | `Libraries/onOffLib.groovy`                          | `0bf47407` | yes — Tuya `0xEF00` switch branch removed; identity        |
| `libraries/battery.groovy`                           | `Libraries/batteryLib.groovy`                        | `0bf47407` | yes — `isTuya()` branch and Tuya helpers removed; identity |
| `libraries/xiaomi.groovy`                            | `Libraries/xiaomiLib.groovy`                         | `0bf47407` | identity only                                              |
| `libraries/button.groovy`                            | `Libraries/buttonLib.groovy`                         | `0bf47407` | identity only                                              |
| `libraries/level.groovy`                             | `Libraries/levelLib.groovy`                          | `0bf47407` | identity only                                              |
| `libraries/meter.groovy`                             | `Libraries/energyLib.groovy`                         | `0bf47407` | identity only                                              |
| `libraries/reporting.groovy`                         | `Libraries/reportingLib.groovy`                      | `0bf47407` | identity only                                              |
| `drivers/aqara-cube-t1-pro/aqara-cube-t1-pro.groovy` | `Drivers/Aqara Cube T1 Pro/Aqara_Cube_T1_Pro.groovy` | `0bf47407` | identity only — includes, namespace, `importUrl`           |

"Identity" means: `namespace` set to `rbn`, `name` set to the file's stem,
upstream `importUrl`/`documentationLink` cleared, provenance notice added.

The Home Assistant bridge app and driver and the Inovelli Zigbee bindings app
under `apps/` and `drivers/` are unrelated third-party code kept verbatim;
their authorship is in their own headers.
