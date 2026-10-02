from __future__ import annotations

from pathlib import Path

import pytest
from fakehub import BASE, FakeHub
from typer.testing import CliRunner

from hubitat import bundle as bundling
from hubitat import push as pushing
from hubitat.cli import app
from hubitat.hub import Hub, HubConfig, HubConfigError, HubError

runner = CliRunner()


@pytest.fixture
def fake() -> FakeHub:
    return FakeHub()


@pytest.fixture
def hub(fake: FakeHub) -> Hub:
    return Hub(HubConfig(BASE), transport=fake.transport())


@pytest.fixture
def probe(tree: Path) -> Path:
    source = tree / "drivers" / "probe" / "probe.groovy"
    bundling.write(source)
    return source


def source(probe: Path) -> str:
    return probe.read_text()


def seed_library(fake: FakeHub, tree: Path) -> int:
    return fake.seed(
        "tiny", "rbn", (tree / "libraries" / "tiny.groovy").read_text(), kind="library"
    )


def test_absent_driver_is_created_after_its_library(
    hub: Hub, fake: FakeHub, probe: Path
) -> None:
    actions = pushing.plan(hub, [probe])
    assert [(a.code, a.kind) for a in actions] == [
        ("library", "created"),
        ("driver", "created"),
    ]
    pushing.apply(hub, actions)
    assert fake.posts() == ["/library/save", "/driver/save"]
    assert fake.libraries[0]["name"] == "tiny"
    assert fake.codes[101]["source"] == source(probe)
    assert "#include rbn.tiny" in fake.codes[101]["source"]


def test_identical_driver_is_unchanged(
    hub: Hub, fake: FakeHub, probe: Path, tree: Path
) -> None:
    seed_library(fake, tree)
    fake.seed("Probe Driver", "rbn", source(probe))
    actions = pushing.plan(hub, [probe])
    assert [a.kind for a in actions] == ["unchanged", "unchanged"]
    pushing.apply(hub, actions)
    assert fake.posts() == []


def test_changed_driver_is_updated_with_fresh_version(
    hub: Hub, fake: FakeHub, probe: Path, tree: Path
) -> None:
    seed_library(fake, tree)
    id = fake.seed("Probe Driver", "rbn", "// old\n", version=7)
    actions = pushing.plan(hub, [probe])
    assert [a.kind for a in actions] == ["unchanged", "updated"]
    assert actions[1].version == 7
    pushing.apply(hub, actions)
    assert fake.posts() == ["/driver/ajax/update"]
    assert fake.codes[id] == {"source": source(probe), "version": 8}


def test_same_name_in_other_namespace_is_ignored(
    hub: Hub, fake: FakeHub, probe: Path, tree: Path
) -> None:
    seed_library(fake, tree)
    other = fake.seed("Probe Driver", "kkossev", "// theirs\n")
    actions = pushing.plan(hub, [probe])
    assert [a.kind for a in actions] == ["unchanged", "created"]
    pushing.apply(hub, actions)
    assert fake.codes[other]["source"] == "// theirs\n"
    assert fake.posts() == ["/driver/save"]


def test_bundled_plan_pushes_the_bundle_alone(
    hub: Hub, fake: FakeHub, probe: Path
) -> None:
    actions = pushing.plan(hub, [probe], bundled=True)
    assert [(a.code, a.kind) for a in actions] == [("driver", "created")]
    assert actions[0].text == bundling.bundle_path(probe).read_text()
    bundling.bundle_path(probe).write_text("// stale\n")
    with pytest.raises(pushing.PushError, match="stale"):
        pushing.plan(hub, [probe], bundled=True)


def test_hub_error_body_surfaces(hub: Hub, fake: FakeHub, probe: Path) -> None:
    fake.seed("Probe Driver", "rbn", "// old\n")
    fake.update_error = "unexpected token @ line 42, column 1"
    with pytest.raises(HubError, match="line 42"):
        pushing.apply(hub, pushing.plan(hub, [probe]))


def test_dry_run_only_reads(
    monkeypatch: pytest.MonkeyPatch, hub: Hub, fake: FakeHub, probe: Path
) -> None:
    fake.seed("Probe Driver", "rbn", "// old\n")
    monkeypatch.setattr(
        Hub, "connect", classmethod(lambda cls, config, transport=None: hub)
    )
    result = runner.invoke(app, ["push", "--dry-run"], env={"HUBITAT_URL": BASE})
    assert result.exit_code == 0, result.output
    assert "would update  Probe Driver" in result.output
    assert fake.posts() == []
    assert {r.method for r in fake.requests} == {"GET"}


def test_push_without_url_names_secretspec() -> None:
    result = runner.invoke(app, ["push", "--dry-run"], env={"HUBITAT_URL": ""})
    assert result.exit_code == 2
    assert "HUBITAT_URL" in result.output
    assert "secretspec" in result.output


def test_unknown_driver_name_is_refused(tree: Path) -> None:
    result = runner.invoke(
        app, ["push", "nope", "--dry-run"], env={"HUBITAT_URL": BASE}
    )
    assert result.exit_code == 2
    assert "unknown driver 'nope'" in result.output


def test_secured_hub_logs_in_without_leaking_credentials(
    fake: FakeHub, probe: Path
) -> None:
    fake.secured = True
    hub = Hub.connect(
        HubConfig(BASE, username="admin", password="right"), transport=fake.transport()
    )
    assert fake.paths() == ["/hub/edit", "/login"]
    assert fake.secured is False
    assert "right" not in " ".join(
        a.describe(dry_run=True) for a in pushing.plan(hub, [probe])
    )

    fake.secured = True
    with pytest.raises(HubError, match="rejected") as rejected:
        Hub.connect(HubConfig(BASE, "admin", "wrong"), transport=fake.transport())
    assert "wrong" not in str(rejected.value)

    with pytest.raises(HubConfigError, match="HUBITAT_USERNAME"):
        Hub.connect(HubConfig(BASE), transport=fake.transport())


def test_from_env_strips_trailing_slash() -> None:
    config = HubConfig.from_env(
        {"HUBITAT_URL": "http://hub.test/", "HUBITAT_USERNAME": ""}
    )
    assert config == HubConfig("http://hub.test", None, None)
    with pytest.raises(HubConfigError, match="HUBITAT_URL"):
        HubConfig.from_env({})
