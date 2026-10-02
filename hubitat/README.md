# hubitat

Groovy libraries and device drivers for the Hubitat Elevation hub, all in the `rbn` namespace, and the small Python tool that bundles, checks, and pushes them.
The libraries are a fork of Krassimir Kossev's [`kkossev/Hubitat`](https://github.com/kkossev/Hubitat) with the Tuya code path removed; drivers are authored here against them.

## How a driver reaches the hub

A driver's source (`drivers/<driver>/<driver>.groovy`) uses `#include rbn.<name>` lines, which the hub resolves against the libraries installed in its Libraries Code.
There are two paths to a hub:

- **Your own hub:** `just hubitat push` creates or updates the libraries the driver includes and then the driver source itself, over the hub's own HTTP API (the one the Hubitat Package Manager uses), skipping anything already identical.
- **Any hub, including other people's:** the Import button and HPM fetch one file and cannot install libraries, so the source is also expanded into `drivers/<driver>/<driver>.bundled.groovy` with each library's code inlined (comments stripped, every line pointing back at its source line, licence notices kept).
  That bundle's raw GitHub URL on `main` is each driver's `importUrl` (Drivers Code → Import) and, once packaged, its HPM manifest `location`; the URL is only valid once the commit is pushed.
  **The bundle is generated and committed; never edit it by hand.**

`bundles/` holds Hubitat _Bundle_ zips (for example the Hubitat Package Manager installer) and is unrelated to the generated `*.bundled.groovy` files.

## Installing with HPM

Every driver directory carries a `packageManifest.json`, and `repository.json` at the top of this tree indexes them all.
The Hubitat Package Manager has two ways in:

- **One package:** Install → From a URL, with the manifest's raw URL, e.g. `https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/drivers/inovelli-vzm31-sn/packageManifest.json`.
- **Everything here:** Package Manager Settings → Add a custom repository, with `https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/repository.json`.
  Install → From a Repository then lists each package as `<name> by John Muchovej`.

Code that reached the hub by hand (Drivers Code → Import, or `just hubitat push`) is invisible to HPM until Package Manager Settings → Match Up adopts it by name and namespace; run Match Up before adding the repository, or HPM offers to install a duplicate.
HPM installs the bundle and nothing else; it has no notion of libraries.
It detects updates by comparing the manifest's `version` string with the one it installed, so a release is always `just hubitat bump <driver> <version>`, which moves `version()`, the manifest, and the bundle together, and `just hubitat check` refuses any drift between them.

## Commands

All of these are `uv run --package hubitat -m hubitat <command>` at the repository root; the `just` recipes just save the typing.

| Recipe                             | What it does                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `just hubitat bundle [SOURCE…]`    | Regenerate every `*.bundled.groovy` (or only the given sources).                                                         |
| `just hubitat check`               | Exit non-zero naming any stale bundle or any HPM manifest that disagrees with its driver; writes nothing.                |
| `just hubitat test`                | Run the package's tests offline.                                                                                         |
| `just hubitat push [DRIVER…]`      | Create or update the libraries each driver includes, then the driver sources, on the hub; `--dry-run` only reads.        |
| `just hubitat push --libraries`    | Only `libraries/*.groovy`, against Libraries Code.                                                                       |
| `just hubitat probe`               | Compile every library's bundled form on the hub through a throwaway include-all driver, report, and delete it.           |
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
On the LAN with hub security off, the `env` provider is enough: `HUBITAT_URL=http://10.32.4.2 SECRETSPEC_PROVIDER=env just hubitat push --dry-run`.
The tool refuses to start without `HUBITAT_URL` and never prints credentials.

## Validation status

Per library, what has actually been observed.
`compile-verified` means the hub compiled it (`just hubitat probe` and a driver save); `runtime-verified` means a paired device ran it and the named behaviour was seen in the log.
Do not read "compiles" as "works".

| Library     | Status           | Device   | Date       |
| ----------- | ---------------- | -------- | ---------- |
| `common`    | runtime-verified | VZM31-SN | 2026-10-02 |
| `switch`    | runtime-verified | VZM31-SN | 2026-10-02 |
| `level`     | runtime-verified | VZM31-SN | 2026-10-02 |
| `meter`     | runtime-verified | VZM31-SN | 2026-10-02 |
| `reporting` | runtime-verified | VZM31-SN | 2026-10-02 |
| `xiaomi`    | runtime-verified | Cube     | 2026-10-02 |
| `button`    | runtime-verified | Cube     | 2026-10-02 |
| `battery`   | runtime-verified | Cube     | 2026-10-02 |

What the VZM31-SN run exercised: driver swap, `refresh` as a single dispatch of four reads, `on`/`off` from the hub, paddle on/off and hold-to-dim as physical events, power (÷10) and energy (÷100) against the raw hex, and Inovelli's private cluster logged as unknown with no error.
Not exercised: `setLevel` from the hub, because the test switch drives a non-dimmable load; physical level events were seen.
What the Cube run exercised, on two paired T1 Pros: pairing onto the driver by fingerprint, Configure as a single dispatch, flip → `pushed`, shake → `doubleTapped`, rotate left → `held`, rotate right → `released`, throw and pick-up as `action` values, `sideUp` tracking, and `battery`/`batteryVoltage` reports parsed from the Xiaomi `0xFCC0` cluster.
A driver is validated only for the behaviour its row's libraries were exercised on; the Inovelli dimmer driver covers `common`, `switch`, `level`, `meter`, `reporting`, and the Aqara Cube driver covers `common`, `switch`, `xiaomi`, `button`, `battery`.

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
Every file is additionally reformatted by the repository's Groovy formatter (whitespace, quoting, comment indentation); upstream changes are tracked by diffing upstream against itself between the recorded commit and its HEAD, so that formatting does not obscure them.

The Home Assistant bridge app and driver and the Inovelli Zigbee bindings app under `apps/` and `drivers/` are unrelated third-party code kept as-is apart from that same formatting; their authorship is in their own headers.
