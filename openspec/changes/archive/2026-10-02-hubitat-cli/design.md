## Context

See proposal.md for motivation.
Facts that shape the approach:

- **The hub's code API, as HPM uses it** (read from HPM 1.9.12): `POST /login` with form fields `username`/`password` yields a session cookie reused on every call; `GET /hub/edit` is fetched as text to detect whether security is enabled; `GET /hub2/userDeviceTypes` returns JSON with `id`, `name`, `namespace` per user driver; `GET /driver/ajax/code?id=` returns JSON with `source` and `version`; `POST /driver/save` with `id: ""`, `version: ""`, `source` creates; `POST /driver/ajax/update` with `id`, `version`, `source` updates (HPM fetches the current `version` immediately before, which is why the tool does too); `GET /driver/editor/deleteJson/<id>` deletes.
  HPM never installs libraries, so the Libraries Code endpoints are not in its source; the Hubitat UI has a Libraries Code page, so parallel endpoints almost certainly exist and are confirmed from the browser's network tab during apply.
- **Repo tooling.**
  `uv 0.12`, root `pyproject.toml` with the `homelab` package at `src/homelab/` built by `uv_build`, dependency groups `dev` (mypy, ruff, ty, …) and `docs`; no workspace yet; no pytest anywhere yet.
  uv distinguishes projects _with_ a build system (built and installed into the environment, so a backend decides where the package directory must be) from projects _without_ one (`uv init --bare`/virtual: dependencies only, never installed, importable only via `sys.path`).
  Workspace members may be either.
  `treefmt` runs `ruff-check` and `ruff-format --isolated` on every `.py`.
  `just` is the task runner; `hubitat/justfile` is already a root module.
  No `secretspec.toml` exists at the root yet; the user's global rules make `secretspec run -- <cmd>` the way secrets reach commands.
- **Existing bundler.**
  `hubitat/scripts/bundle.py`, stdlib only, with the behaviour the previous change's spec pins (include lines blanked, banner once, markers, three refusals, `--check`).
  It is the only consumer of `hubitat/justfile`.
- **`hubitat/` already holds data directories** (`libraries/`, `drivers/`, `bundles/`, `apps/`) and docs.
  Making it a package means `__init__.py` beside them; Python is fine with that, and nothing under those directories is importable.
- **The user is actively trimming `src/homelab/`** and does not want new surface there.
  Everything Hubitat-related is self-contained: no shared types with the rest of the repo.

## Goals / Non-Goals

**Goals:**

- One Python package under `hubitat/` that owns bundling, manifest checking, pushing, probing, and version bumps, runnable with `uv` from the repo root with no installation step.
- Idempotent, scoped hub writes: only `rbn` code, only by name+namespace, never when the hub already has the same bytes.
- Tests for all logic that does not need a hub, so the previous change's throwaway verification steps become permanent.

**Non-Goals:**

- Touching `src/homelab/` in any way.
- Device operations (pairing, driver assignment, Configure).
  The tool moves code; people move devices.
- HPM manifest _generation_ or publishing to HPM's public index.
- A Nix package or wrapper for the tool.
  `uv run` from the dev shell is the whole install story.

## Decisions

### D1. `hubitat/` is a uv workspace member **without a build system**, and the directory is the package

`hubitat/pyproject.toml` (created with `uv init --bare hubitat` from the repo root, then edited) declares `[project] name = "hubitat"`, `requires-python`, and `dependencies = ["httpx", "typer", "pydantic"]`, with `[dependency-groups] dev = ["pytest"]` and **no `[build-system]`**.
The root `pyproject.toml` gains `[tool.uv.workspace] members = ["hubitat"]`; the workspace shares the root `uv.lock` and `.venv`.
Because the project has no build system uv never builds or installs it, so there is no backend demanding a `src/<pkg>/` or `<pkg>/<pkg>/` subdirectory: `hubitat/__init__.py` and `hubitat/__main__.py` sit beside `pyproject.toml`, `libraries/`, and `drivers/`, and the package is importable the ordinary way, from `sys.path` containing the repo root.
Invocation is `uv run --package hubitat -m hubitat <command>` from the repo root (`--package` syncs the member's dependencies into the shared environment; `-m` resolves `hubitat/` from the working directory).
From elsewhere, `uv run --directory <repo> --package hubitat -m hubitat …`.

Why not the alternatives: a project _with_ a build system (the earlier src/flat discussion) forces the package one level down, `hubitat/src/hubitat/`, purely to satisfy a wheel builder we would never use; a root dependency group (the previous draft) gives the code no project identity and leans on `homelab`'s environment; a PEP 723 script cannot be a multi-module package.
Two consequences are accepted: there is no `[project.scripts]` console entry (nothing is installed, so `-m` is the entry point and the `just` recipes carry it), and the module is found via the working directory rather than an install, so every invocation runs with the repo root as cwd (what `--directory` guarantees).

Task 1.1 is the experiment that confirms this on `uv 0.12`: `uv init --bare`, add the member, run `-m hubitat --help` from the root and via `--directory` from elsewhere, and run pytest.
If a virtual workspace member turns out to be rejected or `--package` fails to sync its dependencies, the recorded fallback is the same member _with_ `uv_build` and `src/hubitat/`, data located via `Path(__file__).parents[2]`; the command surface is identical either way.

### D2. Dependencies live in `hubitat/pyproject.toml`; the root only names the member

`typer` and `pydantic` are already dependencies of `homelab`, but `hubitat/` lists them itself so it states its own needs and survives `homelab` being trimmed; `httpx` is new to the tree; `pytest` is the member's `dev` group.
The root `pyproject.toml` changes by exactly the workspace stanza; nothing enters its `[project]`, `[project.scripts]`, or `[dependency-groups]`.
`uv lock` is run once and the single lockfile covers both projects.

### D3. Module split

- `bundle.py` — the existing bundler, moved verbatim except for imports; `BANNER`, markers, refusals unchanged.
  Exposes `bundle(source) -> str`, `bundle_path(source)`, `driver_sources()`.
- `manifest.py` — Pydantic models `PackageManifest`, `ManifestDriver`, `Repository`, `RepositoryPackage`; `driver_identity(source) -> (name, namespace, version)` parsed from the `definition(...)` call and the `static String version()` line; `check_manifest(source)` and `check_repository()` returning lists of `(path, reason)` problems.
  Pydantic gives the UUID and required-field validation for free.
- `hub.py` — `Hub` class over an `httpx.Client` with cookie jar: `security_enabled()`, `login()`, `drivers()`, `driver_code(id)`, `create_driver(source)`, `update_driver(id, source)`, `delete_driver(id)`; library equivalents behind a flag that is enabled only once the endpoints are confirmed.
  Timeouts and `ignoreSSLIssues`-style TLS tolerance mirror HPM (hubs commonly serve self-signed certificates).
- `cli.py` — Typer app with the five commands; thin, no logic.
- `tests/` — `test_bundle.py`, `test_manifest.py`, `test_bump.py` using `tmp_path` fixtures that build a miniature `hubitat/` tree; `hub.py` is exercised only through a fake transport (`httpx.MockTransport`) for the create/update/skip decision logic.
  Tests run as `uv run --package hubitat python -m pytest hubitat/tests` from the root: `python -m pytest` puts the working directory on `sys.path`, which is what makes `import hubitat` resolve without an install or a `pythonpath` setting.

`__init__.py` plus `__main__.py`, not a `main.py` script: a lone `main.py` would make `hubitat/` a directory of top-level modules (`import bundle`, `import hub`) rather than a package, which means no `python -m hubitat`, no relative imports, module names that collide with anything else called `bundle`, and tests that need a `sys.path` hack to find them.
`uv init --bare` creates neither file, so nothing is lost by choosing the package form.

### D4. `push` semantics

Resolve by `(name, namespace)` from `/hub2/userDeviceTypes`; namespace is always `rbn`, read from the source, never guessed.
If absent → `/driver/save` and report `created`.
If present → `GET /driver/ajax/code` → if `source` equals the bundle byte-for-byte → report `unchanged`, no write; else `POST /driver/ajax/update` with the just-read `version` and report `updated`.
`--dry-run` performs the reads and prints the decision.
A driver whose hub namespace is not `rbn` is never touched even if the name matches.
The hub's own error text (compile failures come back in the response body) is surfaced verbatim, followed by the marker-resolved library line when the text contains a bundle line number.

### D5. `probe` is `push` plus cleanup, and leaves nothing behind

Generates the include-all source in a `tempfile` directory from the current list of `hubitat/libraries/*.groovy`, bundles it with the same code path (so the probe exercises the real bundler), pushes it, and deletes it in a `finally`.
Success prints the library list; failure prints the hub error with the resolved library line and exits non-zero.
Replaces the manual procedure in `AGENTS.md`.

### D6. `bump` edits text, not an AST

`version()` and `timeStamp()` are single-line conventions the repo already mandates; `bump` rewrites them with anchored regexes and refuses if either line is missing or appears more than once.
Manifest edits go through the Pydantic model and are written back with stable formatting.
It then calls `bundle` for that driver so `check` is green without a second command.

### D7. Hub configuration through `secretspec`, hub security detected rather than assumed

`secretspec.toml` at the root declares `HUBITAT_URL` (required) and `HUBITAT_USERNAME`/`HUBITAT_PASSWORD` (optional).
Commands run as `secretspec run -- uv run --package hubitat -m hubitat push …`; `hub.py` reads the three variables from the environment and nothing else.
On first contact it checks whether security is enabled the way HPM does; only then does it require and use the credentials, so an unsecured hub needs just the URL.
Credentials never appear in logs or error messages.

### D8. `hubitat/justfile` stays, as thin recipes

`just hubitat bundle|check|test|push|probe|bump` each expand to `uv run --directory {{ justfile_directory() }} --package hubitat -m hubitat …` (and, for hub commands, `secretspec run --` in front).
`just` remains the repo's task runner; the recipes exist so nobody has to remember the flags, and they carry no logic.

### D9. Library push is gated on confirming the endpoints

If `/library/save`, `/library/ajax/code`, `/library/ajax/update`, and a delete endpoint behave like the driver ones, `push --libraries` is enabled and `AGENTS.md` says libraries on the hub are optional development conveniences kept in sync by it.
If they differ or cannot be confirmed, `push` stays driver-only, the flag is absent, and the gap is written down.
Either outcome satisfies the spec; the bundle is what the hub needs.

### D10. `hubitat-runtime-validation` is rebased onto this tool as part of this change

Its tasks 2.2, 3.1, 3.5, and 5.2 and its design D5 reference `just hubitat …`/`bundle.py --check` and by-hand saves.
This change's last task group edits those artifacts so they call the module and use `push` where it replaces pasting, and marks the manifest-check implementation as already delivered here.
Editing another in-flight change's plan is deliberate: it is cheaper than discovering the mismatch during its apply.

## Risks / Trade-offs

- [Hub endpoints behave differently from HPM's use of them] → Every write path is exercised by the first real `push` (the Cube bundle, which must already compile) with `--dry-run` first; HPM's exact request shapes are the starting point and are adjusted from observed responses.
- [`push` matches the wrong driver] → Matching requires namespace `rbn`; kkossev's and Inovelli's drivers can never match.
  Covered by a MockTransport test.
- [A stale `version` is rejected by `/driver/ajax/update`] → The tool always reads `version` immediately before updating, as HPM does.
- [Self-signed hub TLS] → Client tolerates it the way HPM does; `HUBITAT_URL` may be `http://` on a LAN hub.
- [The workspace shares one `.venv`, so `homelab`'s dependencies are present when `hubitat` runs] → Accepted: isolation of _declaration_ is what matters here, and the shared lock is a feature (one resolution for the repo).
- [`-m hubitat` depends on the working directory] → Every documented invocation goes through `--directory <repo>` or runs at the root; the `just` recipes always pass `--directory`.
  The spec's "works from another directory" scenario uses exactly that form.
- [A virtual workspace member misbehaves on this uv version] → Task 1.1 is the experiment; the fallback (`uv_build` + `src/hubitat/`) is recorded in D1 and changes paths, not behaviour.
- [`treefmt --isolated` ruff defaults disagree with the code style] → The package is written to ruff defaults from the start; `jj fix` is the arbiter.

## Migration Plan

1. Repo: workspace member, package, tests, `secretspec.toml`, docs; `uv run --package hubitat python -m pytest hubitat/tests` green; `check` green; bundles byte-identical.
2. Configure `HUBITAT_URL` (and credentials if the hub is secured) in the user's `secretspec` provider.
3. Hub, first contact: `push --dry-run` lists the Cube as `would create` (or `unchanged` if 6.3 of the previous change was done by hand); `push` creates/updates it; a second `push` reports `unchanged`.
4. Hub: `probe` compiles all eight libraries and removes itself; this completes the previous change's 6.2.
5. Hub: confirm Libraries Code endpoints from the browser; enable `--libraries` or document the gap (D9).
6. Rebase `hubitat-runtime-validation`'s artifacts; commit per group.
7. Rollback: delete the `rbn` drivers from Drivers Code (or `push` the previous bundle); nothing on the hub is referenced by a device.

## Open Questions

- Whether a future `pull` (hub → repo diff) is worth adding for drivers edited on the hub by mistake.
  Deferrable; `push --dry-run` already shows the mismatch exists.
- Whether `probe` should also run in a pre-commit hook.
  Deferrable; it needs a hub, so probably not.
