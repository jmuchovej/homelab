from __future__ import annotations

from pathlib import Path

import pytest
from fakehub import BASE, FakeHub

from hubitat import bundle as bundling
from hubitat import push as pushing
from hubitat.hub import Hub, HubConfig


@pytest.fixture
def fake() -> FakeHub:
    return FakeHub()


@pytest.fixture
def hub(fake: FakeHub) -> Hub:
    return Hub(HubConfig(BASE), transport=fake.transport())


def probe_bundle(tree: Path) -> str:
    source = tree / "scratch" / "probe.groovy"
    source.parent.mkdir()
    source.write_text(pushing.probe_source(pushing.library_names()))
    return bundling.bundle(source)


def test_probe_source_includes_every_library_and_parses(tree: Path) -> None:
    text = pushing.probe_source(["tiny", "other"])
    assert "#include rbn.tiny\n#include rbn.other\n" in text
    source = tree / "scratch" / "p.groovy"
    source.parent.mkdir()
    source.write_text(text)
    from hubitat import manifest as manifests

    assert manifests.driver_identity(source) == (pushing.PROBE_NAME, "rbn", "0.0.0")


def test_probe_success_creates_then_deletes(
    hub: Hub, fake: FakeHub, tree: Path
) -> None:
    assert pushing.probe(hub) == ["tiny"]
    assert fake.posts() == ["/driver/save"]
    assert "/driver/editor/deleteJson/100" in fake.paths()
    assert fake.drivers == []
    assert not (tree / "drivers" / "probe" / "probe.bundled.groovy").exists()


def test_probe_failure_still_deletes_and_resolves_line(
    hub: Hub, fake: FakeHub, tree: Path
) -> None:
    bundled = probe_bundle(tree).splitlines()
    marker_line = next(
        i for i, line in enumerate(bundled, start=1) if line.endswith(" // rbn.tiny#L2")
    )
    fake.save_error = f"Script1.groovy: {marker_line}: unexpected token @ line {marker_line}, column 5."
    # A failed save still creates nothing, but a stale probe from an earlier run must be swept.
    stale = fake.seed(pushing.PROBE_NAME, "rbn", "// stale probe\n")
    fake.update_error = fake.save_error
    with pytest.raises(pushing.ProbeError) as failure:
        pushing.probe(hub)
    message = str(failure.value)
    assert f"line {marker_line}" in message
    assert "tiny.groovy:2" in message
    assert fake.paths()[-1] == f"/driver/editor/deleteJson/{stale}"
    assert fake.drivers == []


def test_probe_leaves_other_namespaces_alone(
    hub: Hub, fake: FakeHub, tree: Path
) -> None:
    theirs = fake.seed(pushing.PROBE_NAME, "kkossev", "// theirs\n")
    pushing.probe(hub)
    assert theirs in fake.codes
    assert [d["id"] for d in fake.drivers] == [theirs]
