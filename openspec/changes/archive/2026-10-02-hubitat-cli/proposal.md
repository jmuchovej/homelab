## Why

Everything that moves Hubitat code between this repo and the hub is still by hand: the bundler is a loose script behind a `just` recipe, every "save this on the hub" step in the previous two changes is a human pasting into Drivers Code, and the include-all compile probe is a procedure in `AGENTS.md`.
The hub exposes the HTTP endpoints that make all of that scriptable — HPM itself is nothing more than a Groovy app calling `/login`, `/hub2/userDeviceTypes`, `/driver/ajax/code`, `/driver/save`, and `/driver/ajax/update` — so a small Python package can bundle, check, push, and probe in one tool.
It belongs in `hubitat/` itself, as a plain Python package run through `uv`, rather than in the `homelab` CLI, which is being trimmed and whose assumptions this work should not inherit.
Doing it before `hubitat-runtime-validation` means that change's manifest check is written once, in the right place, and its hub-side steps become commands instead of instructions.

## What Changes

- Make `hubitat/` a uv workspace member with its own `pyproject.toml` (started with `uv init --bare`) and **no build system**, so uv treats it as a dependency-bearing project it never installs — which is what lets the directory itself be the importable package: `__init__.py`, `__main__.py`, and modules `cli.py` (Typer), `bundle.py` (moved from `scripts/`, same behaviour), `manifest.py` (Pydantic models for `packageManifest.json` and `repository.json` plus the agreement checks), `hub.py` (an `httpx` client for the hub's code endpoints), `push.py`.
  Data directories (`libraries/`, `drivers/`, `bundles/`, `apps/`) stay where they are; code finds them relative to its own file.
  Tests live in `hubitat/tests/` and turn the throwaway bundler checks from the previous change into pytest cases.
  `hubitat/scripts/` is removed.
  The first task is the experiment that confirms the virtual-member arrangement on this uv; the fallback (`uv_build` with `src/hubitat/`) is recorded and changes paths only.
- Run it as `uv run --package hubitat -m hubitat <command>` from the repo root.
  The root `pyproject.toml` gains only `[tool.uv.workspace] members = ["hubitat"]`; the member's dependencies (`httpx`, `typer`, `pydantic`; `pytest` in its dev group) live in `hubitat/pyproject.toml`; one `uv.lock` covers both.
  No entry in the root's `[project.scripts]` or dependency groups, no import from or into `src/homelab/`.
  `hubitat/justfile` becomes thin recipes that delegate to that invocation.
- Commands: `bundle [SOURCE…]` and `check` (as today, plus manifest agreement when a manifest exists); `push [DRIVER…] [--dry-run]` (log in if the hub requires it, resolve each driver by name+namespace, create via `/driver/save` or update via `/driver/ajax/update`, skipping drivers whose hub source already equals the bundle); `probe` (bundle an include-all source in a temp dir, push it, delete it from the hub, report compile success or the marker-mapped error); `bump DRIVER VERSION` (rewrite `version()`/`timeStamp()`, the manifest `version`/`dateReleased` if present, and re-bundle).
  Library push is included only if the hub's Libraries Code endpoints are confirmed during apply; otherwise it is left as a documented gap.
- Hub address and credentials come through `secretspec`: a root `secretspec.toml` declaring `HUBITAT_URL` (required) and `HUBITAT_USERNAME`/`HUBITAT_PASSWORD` (optional, used only when the hub has security enabled).
  The tool refuses to run `push`/`probe` without `HUBITAT_URL` and never prints credentials.
- Update `hubitat/AGENTS.md` (the package layout, how to run and test it, the push model and its idempotence, the probe) and `hubitat/README.md` (commands, the `secretspec` variables).
- Rebase `hubitat-runtime-validation`'s artifacts onto this tool: its task 3.1 (extend `bundle.py --check`) becomes "manifest models and checks already exist; add the manifests and run `check`", its hub steps 5.2/6.x use `push` where that replaces pasting, and its D5 points at `manifest.py`.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `hubitat-drivers`: gains requirements for the Python package and its commands (`bundle`, `check`, `push`, `probe`, `bump`), the `secretspec` contract for hub access, idempotent push semantics, and the test suite.
  The earlier bundler requirements keep their wording; only the invocation changes from a script path to the module.
  The capability is introduced by the in-flight `hubitat-rbn-libraries`; this delta adds requirements only.

## Impact

- **Hub-side**: `push` writes to Drivers Code (and Libraries Code if confirmed).
  It only ever creates or updates `rbn`-namespace code it resolved by name, and it reads the current source first and skips when identical, so re-running is safe.
  `probe` creates and then deletes one driver named `rbn include-all probe`.
  Nothing touches devices.
- **Sequencing**: before `hubitat-runtime-validation`, which is amended to use the tool.
  After `hubitat-rbn-libraries`'s repo side; its still-open hub tasks (6.1–6.3) can be done with `push` and `probe` once this lands, which is the first real exercise of the tool.
- **Root `pyproject.toml`**: one new `[tool.uv.workspace]` stanza and a `uv.lock` update that now also covers the member.
  No change to `homelab`'s dependencies, scripts, or package.
- **Formatting**: `treefmt` already runs `ruff-check`/`ruff-format` on every `.py` in the tree, so the package is formatted and linted by the existing hook with no configuration.
- **Unknowns resolved during apply, not now**: whether Libraries Code has `/library/save` and `/library/ajax/update` parallel to the driver endpoints (HPM never installs libraries, so its source is silent), and whether `/driver/ajax/update` rejects a stale `version` (HPM reads it back first, which the tool also does).
  Both are observed on the hub in the first push tasks.
- **Not touched**: `src/homelab/`, the driver and library sources, the bundle format, the `kkossev.*` entries on the hub.
