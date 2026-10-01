# hubitat

Groovy libraries and device drivers for the Hubitat Elevation hub, all in the `rbn` namespace, and the small Python tool that bundles, checks, and pushes them.
The libraries are a fork of Krassimir Kossev's [`kkossev/Hubitat`](https://github.com/kkossev/Hubitat) with the Tuya code path removed; drivers are authored here against them.

## How a driver reaches the hub

A driver's source (`drivers/<driver>/<driver>.groovy`) uses `#include rbn.<name>` lines.
Hubitat imports a single file, so the source is expanded into `drivers/<driver>/<driver>.bundled.groovy` with each library inlined.
**The bundle is generated and committed; never edit it by hand.**

There are two paths from the bundle to a hub:

- **Your own hub, while developing:** `just hubitat push` creates or updates the driver over the hub's own HTTP API (the one the Hubitat Package Manager uses) and skips drivers whose code is already identical.
- **Any hub, including other people's:** the bundle's raw GitHub URL on `main` is each driver's `importUrl` (Drivers Code → Import) and, once packaged, its HPM manifest `location`.
  That URL is only valid once the commit is pushed.

`bundles/` holds Hubitat _Bundle_ zips (for example the Hubitat Package Manager installer) and is unrelated to the generated `*.bundled.groovy` files.

## Commands

All of these are `uv run --package hubitat -m hubitat <command>` at the repository root; the `just` recipes just save the typing.

| Recipe                             | What it does                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `just hubitat bundle [SOURCE…]`    | Regenerate every `*.bundled.groovy` (or only the given sources).                                                         |
| `just hubitat check`               | Exit non-zero naming any stale bundle or any HPM manifest that disagrees with its driver; writes nothing.                |
| `just hubitat test`                | Run the package's tests offline.                                                                                         |
| `just hubitat push [DRIVER…]`      | Create or update `rbn` drivers on the hub from their bundles; `--dry-run` reads and reports without writing.             |
| `just hubitat probe`               | Compile every library on the hub through a throwaway include-all driver, report, and delete it.                          |
| `just hubitat bump DRIVER VERSION` | Set the driver's `version()`/`timeStamp()`, the manifest `version`/`dateReleased` if present, and regenerate the bundle. |

`DRIVER` is the directory name under `drivers/`, e.g. `aqara-cube-t1-pro`.

### Hub access

`push` and `probe` read the hub's address and credentials from the environment, provided by [`secretspec`](https://secretspec.dev) from the root `secretspec.toml`:

| Variable           | Required | Purpose                                                        |
| ------------------ | -------- | -------------------------------------------------------------- |
| `HUBITAT_URL`      | yes      | Base URL of the hub, e.g. `http://10.32.x.y`.                  |
| `HUBITAT_USERNAME` | no       | Only when the hub has security enabled (detected on each run). |
| `HUBITAT_PASSWORD` | no       | Same.                                                          |

`secretspec check --explain --reason '<why>'` shows what is configured without revealing values; the `just` recipes wrap the command in `secretspec run` for you.
The tool refuses to start without `HUBITAT_URL` and never prints credentials.

## Validation status

**Compile-verified only.**
The `rbn` libraries and the Aqara Cube T1 Pro driver have been saved on the hub and compile; no device has been run on them yet.
Runtime validation on a paired device is tracked as a separate OpenSpec change. Do not read "compiles" as "works".

## Attribution

The files below are derived from [`kkossev/Hubitat`](https://github.com/kkossev/Hubitat), © Krassimir Kossev, licensed under the Apache License, Version 2.0.
Each file keeps its original license header and states, directly beneath it, that it has been modified and from which upstream path and commit.
Per Apache-2.0 §4 those in-file notices are the authoritative record; this table is a summary.

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

"Identity" means: `namespace` set to `rbn`, `name` set to the file's stem, upstream `importUrl`/`documentationLink` cleared, provenance notice added.

The Home Assistant bridge app and driver and the Inovelli Zigbee bindings app under `apps/` and `drivers/` are unrelated third-party code kept verbatim; their authorship is in their own headers.
