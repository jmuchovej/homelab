from __future__ import annotations

from pathlib import Path

import pytest
from fakehub import BASE, FakeHub
from typer.testing import CliRunner

from hubitat import manifest as manifests
from hubitat import push as pushing
from hubitat.cli import app
from hubitat.hub import Hub, HubConfig

runner = CliRunner()


@pytest.fixture
def fake() -> FakeHub:
    return FakeHub()


@pytest.fixture
def hub(fake: FakeHub) -> Hub:
    return Hub(HubConfig(BASE), transport=fake.transport())


def tiny(tree: Path) -> Path:
    return tree / "libraries" / "tiny.groovy"


def test_library_identity_reads_multiline_header(tree: Path) -> None:
    path = tiny(tree)
    path.write_text(
        "library(\n    base: 'driver', author: 'x', name: 'tiny', namespace: 'rbn',\n"
        "    importUrl: '', documentationLink: '',\n    version: '1.0.0'\n)\n"
        "def tinyHello() { return 'hi' }\n"
    )
    assert manifests.library_identity(path) == ("tiny", "rbn", "1.0.0")


def test_absent_library_is_created(hub: Hub, fake: FakeHub, tree: Path) -> None:
    actions = pushing.plan_libraries(hub, [tiny(tree)])
    assert [(a.kind, a.code) for a in actions] == [("created", "library")]
    pushing.apply(hub, actions)
    assert fake.posts() == ["/library/save"]
    assert fake.libraries[0]["name"] == "tiny"
    assert fake.codes[100]["source"] == tiny(tree).read_text()
    assert fake.drivers == []


def test_identical_library_is_unchanged(hub: Hub, fake: FakeHub, tree: Path) -> None:
    fake.seed("tiny", "rbn", tiny(tree).read_text(), kind="library")
    actions = pushing.plan_libraries(hub, [tiny(tree)])
    assert [a.kind for a in actions] == ["unchanged"]
    pushing.apply(hub, actions)
    assert fake.posts() == []


def test_changed_library_is_updated(hub: Hub, fake: FakeHub, tree: Path) -> None:
    id = fake.seed("tiny", "rbn", "// old\n", version=3, kind="library")
    actions = pushing.plan_libraries(hub, [tiny(tree)])
    assert [a.kind for a in actions] == ["updated"]
    pushing.apply(hub, actions)
    assert fake.posts() == ["/library/ajax/update"]
    assert fake.codes[id] == {"source": tiny(tree).read_text(), "version": 4}


def test_other_namespace_library_is_ignored(
    hub: Hub, fake: FakeHub, tree: Path
) -> None:
    theirs = fake.seed("tiny", "kkossev", "// theirs\n", kind="library")
    pushing.apply(hub, pushing.plan_libraries(hub, [tiny(tree)]))
    assert fake.codes[theirs]["source"] == "// theirs\n"
    assert len(fake.libraries) == 2


def test_delete_library_uses_edit_route(hub: Hub, fake: FakeHub, tree: Path) -> None:
    id = fake.seed("tiny", "rbn", "// x\n", kind="library")
    hub.delete_library(id)
    assert fake.paths()[-1] == f"/library/edit/deleteJson/{id}"
    assert fake.libraries == []


def test_cli_push_libraries_dry_run(
    monkeypatch: pytest.MonkeyPatch, hub: Hub, fake: FakeHub, tree: Path
) -> None:
    monkeypatch.setattr(
        Hub, "connect", classmethod(lambda cls, config, transport=None: hub)
    )
    result = runner.invoke(
        app, ["push", "--libraries", "--dry-run"], env={"HUBITAT_URL": BASE}
    )
    assert result.exit_code == 0, result.output
    assert "would create  library tiny" in result.output
    assert fake.posts() == []

    result = runner.invoke(
        app, ["push", "--libraries", "nope"], env={"HUBITAT_URL": BASE}
    )
    assert result.exit_code == 2
    assert "unknown library 'nope'" in result.output
