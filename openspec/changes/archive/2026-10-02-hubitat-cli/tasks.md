## 1. Workspace member and package skeleton (1.1 is the experiment from design D1)

- [x] 1.1 From the repo root run `uv init --bare hubitat` (it must create only `hubitat/pyproject.toml`; verify no `main.py`, `README.md`, or `.python-version` appeared under `hubitat/` and nothing else in the tree changed).
  Edit that file: `[project] name = "hubitat"`, `version = "0.1.0"`, `requires-python = ">=3.13"`, `dependencies = ["httpx>=…", "typer>=…", "pydantic>=…"]`, `[dependency-groups] dev = ["pytest>=…"]`, and confirm it has **no** `[build-system]`.
  Add `[tool.uv.workspace] members = ["hubitat"]` to the root `pyproject.toml`, then `uv lock`.
  Verify: `uv run --package hubitat python -c 'import httpx, typer, pydantic, pytest'` exits 0; `find . -name uv.lock -not -path './.venv/*'` prints only the root lock; `jj diff --stat pyproject.toml` shows only the workspace stanza.
  If `uv` rejects a member without a build system or `--package` does not sync its dependencies, record the exact error in design D1 and switch to the fallback there (`[build-system]` with `uv_build`, package at `hubitat/src/hubitat/`, `ROOT = Path(__file__).parents[2]`), adjusting the paths in the tasks below
- [x] 1.2 Create `hubitat/__init__.py` (package docstring, `__version__`, and `ROOT = Path(__file__).parent` plus `LIBRARIES`, `DRIVERS` paths), `hubitat/__main__.py` (`from .cli import app; app()`), and an empty `hubitat/cli.py` Typer app.
  Verify `uv run --package hubitat -m hubitat --help` exits 0 at the root, and `cd /tmp && uv run --directory <repo> --package hubitat -m hubitat --help` also exits 0
- [x] 1.3 Move `hubitat/scripts/bundle.py` to `hubitat/bundle.py`, replacing its `HUBITAT = Path(__file__).resolve().parent.parent` with the package's `ROOT`, keeping `BANNER`, the include regex, the three refusals, `bundle()`, `bundle_path()`, and the default-sources logic unchanged; delete `hubitat/scripts/`.
  Verify `ls hubitat/scripts` fails and `rg -n 'parent.parent' hubitat/bundle.py` is empty
- [x] 1.4 Wire `bundle [SOURCE…]` and `check` into `cli.py` over `bundle.py`.
  Verify `uv run --package hubitat -m hubitat bundle` rewrites the Cube bundle byte-identically (`jj diff hubitat/drivers` is empty afterwards) and `… check` exits 0

## 2. Tests for the bundler (test-first for everything that follows)

- [x] 2.1 Create `hubitat/tests/conftest.py` with a `tree` fixture that builds a miniature package tree under `tmp_path` (`libraries/tiny.groovy`, `drivers/probe/probe.groovy`) and monkeypatches `hubitat.ROOT`/`LIBRARIES`/`DRIVERS` to it.
  Verify `uv run --package hubitat python -m pytest hubitat/tests -q` collects 0 tests and exits 5 (no tests yet) without import errors
- [x] 2.2 Write `hubitat/tests/test_bundle.py`: line-number preservation (`metadata` keeps its line), banner emitted once when the source lacks it and not duplicated when the source ends with it, per-line markers with correct numbering, and the three refusals (missing library, nested `#include`, triple-quoted string) each raising with the library named; plus `--check` stale/fresh behaviour through the CLI runner.
  Verify `uv run --package hubitat python -m pytest hubitat/tests/test_bundle.py -q` passes with at least 8 tests

## 3. Manifest models and checks

- [x] 3.1 Write `hubitat/manifest.py`: Pydantic models `ManifestDriver` (`id: UUID`, `name`, `namespace`, `location: HttpUrl`, `required: bool`), `PackageManifest` (`packageName`, `author`, `version`, `minimumHEVersion`, `dateReleased`, `releaseNotes`, `documentationLink`, `drivers: list[ManifestDriver]`), `RepositoryPackage` (`id: UUID`, `name`, `category`, `location`, `description`, `tags`), `Repository` (`author`, `gitHubUrl`, `payPalUrl`, `packages`); `driver_identity(source: Path) -> DriverIdentity(name, namespace, version)` parsed with anchored regexes from `definition(` and `static String version()`; `check_manifest(source) -> list[Problem]` asserting version equality, exactly one driver, namespace `rbn`, name match, `location` ending in `/hubitat/drivers/<d>/<d>.bundled.groovy`; `check_repository() -> list[Problem]` asserting every index entry's manifest exists and every manifest is indexed.
  Verify `uv run --package hubitat python -c 'import hubitat.manifest'` exits 0
- [x] 3.2 Write `hubitat/tests/test_manifest.py` covering: agreement passes; version drift, wrong location, wrong name, wrong namespace, non-UUID id, two drivers, missing manifest (when the check is told one is required), dangling index entry, and unindexed manifest each produce exactly one `Problem` naming the right file.
  Verify `uv run --package hubitat python -m pytest hubitat/tests/test_manifest.py -q` passes with at least 10 tests
- [x] 3.3 Make `check` run `check_manifest` for every driver that has a sibling `packageManifest.json` and `check_repository` when `hubitat/repository.json` exists, printing `error: <file>: <reason>` lines and exiting 1 on any problem.
  Verify `… check` still exits 0 on the current tree (no manifests yet) and that a temporary manifest with a wrong version under `hubitat/drivers/aqara-cube-t1-pro/` makes it exit 1 naming the file; remove the temporary manifest

## 4. Hub client

- [x] 4.1 Add `secretspec.toml` at the repository root declaring `HUBITAT_URL` (required, description "Base URL of the Hubitat hub, e.g. http://10.69.x.y") and `HUBITAT_USERNAME`/`HUBITAT_PASSWORD` (optional, "only when hub security is enabled"); `jj file track` it.
  Verify `secretspec check --explain --reason 'hubitat-cli task 4.1'` lists `HUBITAT_URL` as missing and the two credentials as optional
- [x] 4.2 Write `hubitat/hub.py`: `HubConfig.from_env()` reading the three variables (raising a `HubConfigError` that names `HUBITAT_URL` and `secretspec` when the URL is unset); `Hub` over `httpx.Client(base_url, cookies, timeout=30, verify=False)` with `security_enabled()` (GET `/hub/edit`, HPM's detection), `login()` (POST `/login` form `username`/`password`), `drivers()` (GET `/hub2/userDeviceTypes` → list of `HubDriver(id, name, namespace)`), `driver_code(id)` (GET `/driver/ajax/code` → `source`, `version`), `create_driver(source)` (POST `/driver/save`), `update_driver(id, version, source)` (POST `/driver/ajax/update`), `delete_driver(id)` (GET `/driver/editor/deleteJson/<id>`); every method raises `HubError` with the hub's response text on non-2xx or on an error body; no method logs credentials.
  Verify `uv run --package hubitat python -c 'import hubitat.hub'` exits 0 and `rg -n 'password' hubitat/hub.py` shows it used only in the login form body
- [x] 4.3 Write `hubitat/push.py` with `plan(hub, sources) -> list[Action]` (`created`/`updated`/`unchanged` per driver, from `drivers()` + `driver_code()` comparison, namespace `rbn` enforced) and `apply(hub, actions)`; wire `push [DRIVER…] [--dry-run]` into `cli.py`, resolving `DRIVER` names to `hubitat/drivers/<d>/` and refusing unknown names.
  Verify `uv run --package hubitat -m hubitat push --dry-run` without `HUBITAT_URL` exits non-zero naming `HUBITAT_URL` and `secretspec`
- [x] 4.4 Write `hubitat/tests/test_push.py` using `httpx.MockTransport`: absent → `created`; present with identical source → `unchanged` and no POST; present with different source → `updated` with the freshly read `version`; a same-named driver in namespace `kkossev` is ignored; `--dry-run` issues GETs only; a hub error body surfaces in the exception.
  Verify `uv run --package hubitat python -m pytest hubitat/tests/test_push.py -q` passes with at least 6 tests

## 5. probe and bump

- [x] 5.1 Write `probe` in `cli.py`/`push.py`: build the include-all source (`metadata { definition(name: 'rbn include-all probe', namespace: 'rbn', author: 'probe') { capability 'Sensor' } }`, `DEVICE_TYPE`, one `#include rbn.<name>` per file in `hubitat/libraries/`) in a `tempfile.TemporaryDirectory`, bundle it through `bundle.bundle()`, push it, then delete it in a `finally`; on a hub compile error, map any `line N` in the error text through the bundle's marker suffix to `<library>.groovy:<n>` and print both.
  Verify a MockTransport test (`test_probe.py`) shows create → delete on success and create → delete on failure, and `rg -n 'probe' hubitat/drivers hubitat/libraries` is empty
- [x] 5.2 Write `bump DRIVER VERSION`: rewrite the single `static String version() { "…" }` and `static String timeStamp() {"…"}` lines (refuse if either is missing or duplicated), update `version` and `dateReleased` in a sibling manifest if present via the Pydantic model, then re-bundle that driver.
  Verify `hubitat/tests/test_bump.py` (3+ tests: source only, source+manifest, refusal on missing `version()` line) passes, and that `bump` on a copy of the Cube source followed by `check` exits 0

## 6. Just recipes and docs

- [x] 6.1 Rewrite `hubitat/justfile` as thin recipes: `bundle *ARGS`, `check`, `bump DRIVER VERSION` → `uv run --directory {{ justfile_directory() }} --package hubitat -m hubitat …`; `test` → `uv run --directory {{ justfile_directory() }} --package hubitat python -m pytest hubitat/tests`; `push *ARGS` and `probe` → the `-m hubitat` form wrapped in `secretspec run --reason 'just hubitat <recipe>' --`.
  Verify `just hubitat` lists all six, `just hubitat check` and `just hubitat test` exit 0
- [x] 6.2 Update `hubitat/AGENTS.md`: that `hubitat/` is a virtual uv workspace member (own `pyproject.toml`, no build system, never installed, the directory is the package, invoked with `--package hubitat -m hubitat` from the repo root or via `--directory`); the rule that logic lives in modules and `cli.py` stays thin; how to run and test; the `push` model (name+namespace resolution, `rbn` only, unchanged-skip, read-version-then-update); `probe` replaces the manual include-all procedure (delete that section); `secretspec` variables; the no-coupling rule with `src/homelab/`.
  Verify `rg -n 'scripts/bundle.py|Never commit the probe' hubitat/AGENTS.md` is empty
- [x] 6.3 Update `hubitat/README.md`: command table, `secretspec` setup, and that `push` is how code reaches the hub during development while HPM/raw URL is how it reaches other hubs.
  Verify the three `secretspec` variable names appear
- [x] 6.4 Run `jj fix`, `uv run --package hubitat python -m pytest hubitat/tests -q`, `uv run --package hubitat -m hubitat check`, and `prek run --files <changed files>`; verify all pass and `jj diff hubitat/drivers` is still empty (bundles unchanged by the move).
  _Note: `treefmt` was run directly on the changed files instead of `jj fix` because the working copy also held unrelated uncommitted work; the `pre-commit-hook-ensure-sops` hook crashes on `secretspec.toml` because its `files` pattern is `^secrets` (matches `secretspec…`) — hook config fix, not a tool fix._
- [x] 6.5 Commit per group with explicit filesets: `feat(hubitat): python package with bundle/check commands` (groups 1–2), `feat(hubitat): manifest models and check` (3), `feat(hubitat): hub client and push` (4), `feat(hubitat): probe and bump` (5), `docs(hubitat): cli usage, agent rule, secretspec` (6.1–6.3).
  Verify each `jj diff -r <rev> --stat` lists only its files and the root `pyproject.toml`, `hubitat/pyproject.toml`, and `uv.lock` ride with the first

## 7. First contact with the hub (by hand for secrets; commands otherwise)

- [x] 7.1 Configure `HUBITAT_URL` (and credentials if the hub has security enabled) in your `secretspec` provider; verify `secretspec check --explain --reason 'hubitat-cli task 7.1'` reports nothing missing.
  _Done 2026-10-01 with the `env` provider (`HUBITAT_URL=http://10.32.4.2 SECRETSPEC_PROVIDER=env just hubitat …`); the hub has security disabled, so no credentials are needed and none were configured in 1Password._
- [x] 7.2 `just hubitat push --dry-run`; verify it lists `Aqara Cube T1 Pro` as `would create` (or `unchanged`/`would update` if `hubitat-rbn-libraries` 6.3 was already done by hand) and nothing else.
  _Reported `would create` — no `rbn` Cube driver existed on the hub._
- [x] 7.3 `just hubitat push`; verify it reports `created` (or `updated`), Drivers Code shows `Aqara Cube T1 Pro` in namespace `rbn`, and a second `just hubitat push` reports `unchanged`.
  This completes `hubitat-rbn-libraries` task 6.3; tick it there with a note.
  _`created` (hub id 822), then `unchanged`; `/hub2/userDeviceTypes` lists exactly one `rbn` driver._
- [x] 7.4 `just hubitat probe`; verify it reports all eight libraries compiled and that no driver named `rbn include-all probe` remains on the hub.
  This completes `hubitat-rbn-libraries` task 6.2; tick it there with a note.
  _`compiled 8 libraries: battery, button, common, level, meter, reporting, switch, xiaomi`; no probe driver left on the hub._
- [x] 7.5 _(done 2026-10-01 without the browser: the hub's UI JavaScript named the routes and read-only GETs plus one create/update/delete round-trip on `button` confirmed them — `/hub2/userLibraries`, `/library/ajax/code?id=`, `POST /library/save` → 302 `Location: /library/editor/<id>`, `POST /library/ajax/update` → `{status: "success"}`, `GET /library/edit/deleteJson/<id>` → `{success: true}` (the driver-style `editor/deleteJson` is 404 for libraries).
  `push --libraries` implemented with MockTransport tests; first run created eight, second run reported eight `unchanged`.)_ (browser, by hand) On the hub's Libraries Code page, save an existing `rbn` library once with the network tab open and record the request paths and bodies for list, read, save, update, and delete.
  If they parallel the driver endpoints, implement `push --libraries` in `hub.py`/`push.py` with the same unchanged-skip semantics, add MockTransport tests, and verify `just hubitat push --libraries` reports eight `unchanged`/`updated`; if not, record the observed shapes in `AGENTS.md` as the gap and leave the flag absent.
  Either way this completes `hubitat-rbn-libraries` task 6.1 (by push or by the hand-saves already done); tick it there with a note
- [x] 7.6 Commit any 7.5 code as `feat(hubitat): push libraries` and the `hubitat-rbn-libraries` task ticks as `chore(openspec): record hub steps done via hubitat-cli`

## 8. Rebase `hubitat-runtime-validation` onto the tool

- [x] 8.1 Edit `openspec/changes/hubitat-runtime-validation/tasks.md`: 2.2 and 3.5 use `just hubitat bundle`/`check` unchanged in wording but note the module; 3.1 becomes "manifest models and checks exist from `hubitat-cli`; confirm `check` fails on a missing manifest and proceed to 3.2"; 5.2 keeps the HPM install-from-URL test (it is the HPM path under test) but adds "the driver was first pushed with `just hubitat push` in 4.x and HPM Match Up adopts it"; 6.3 uses `just hubitat bump inovelli-vzm31-sn 0.1.1`.
  Edit its `design.md` D5 to point at `manifest.py`.
  Verify `openspec validate hubitat-runtime-validation --type change --strict --no-interactive` passes
- [x] 8.2 Commit as `chore(openspec): rebase hubitat-runtime-validation onto hubitat-cli` and mark this change's tasks complete (group 7 stays open until the hub secrets are configured); verify `openspec status --change hubitat-cli` shows all artifacts done and `openspec validate hubitat-cli --type change --strict` passes
