from __future__ import annotations

import json
import shutil
from datetime import UTC, datetime
from pathlib import Path

import pytest
from typer.testing import CliRunner

import hubitat
from hubitat import bump as bumping
from hubitat import bundle as bundling
from hubitat import manifest as manifests
from hubitat.cli import app

runner = CliRunner()
WHEN = datetime(2026, 10, 1, 18, 5, tzinfo=UTC)
REAL_ROOT = Path(hubitat.__file__).resolve().parent


def probe(tree: Path) -> Path:
    return tree / "drivers" / "probe" / "probe.groovy"


def test_bump_source_only(tree: Path) -> None:
    written = bumping.bump(probe(tree), "2.0.0", WHEN)
    assert written == [probe(tree), bundling.bundle_path(probe(tree))]
    text = probe(tree).read_text()
    assert 'static String version() { "2.0.0" }' in text
    assert 'static String timeStamp() { "2026/10/01 06:05 PM" }' in text
    assert manifests.driver_identity(probe(tree)).version == "2.0.0"
    assert not bundling.is_stale(probe(tree))


def test_bump_source_and_manifest(tree: Path) -> None:
    manifest = manifests.manifest_path(probe(tree))
    manifest.write_text(
        json.dumps(
            {
                "packageName": "Probe Driver",
                "author": "test",
                "version": "1.2.3",
                "minimumHEVersion": "2.3.0",
                "dateReleased": "2020-01-01",
                "drivers": [
                    {
                        "id": "4f1c0e3a-6d4b-4a7a-9d1e-0f2b3c4d5e6f",
                        "name": "Probe Driver",
                        "namespace": "rbn",
                        "location": "https://x.test/hubitat/drivers/probe/probe.bundled.groovy",
                        "required": True,
                    }
                ],
            }
        )
    )
    written = bumping.bump(probe(tree), "1.3.0", WHEN)
    assert manifest in written
    data = json.loads(manifest.read_text())
    assert data["version"] == "1.3.0"
    assert data["dateReleased"] == "2026-10-01"
    assert manifests.check_manifest(probe(tree)) == []


def test_bump_refuses_missing_version_line(tree: Path) -> None:
    path = probe(tree)
    path.write_text(
        path.read_text().replace('static String version() { "1.2.3" }\n', "")
    )
    with pytest.raises(bumping.BumpError, match="version\\(\\)' line, found 0"):
        bumping.bump(path, "9.9.9", WHEN)


def test_bump_refuses_duplicate_timestamp_line(tree: Path) -> None:
    path = probe(tree)
    path.write_text(
        path.read_text() + 'static String timeStamp() {"2000/01/01 01:00 AM"}\n'
    )
    with pytest.raises(bumping.BumpError, match="timeStamp\\(\\)' line, found 2"):
        bumping.bump(path, "9.9.9", WHEN)


def test_bump_cube_copy_keeps_check_green(tree: Path) -> None:
    for library in (REAL_ROOT / "libraries").glob("*.groovy"):
        shutil.copy(library, tree / "libraries" / library.name)
    cube = tree / "drivers" / "aqara-cube-t1-pro"
    cube.mkdir()
    shutil.copy(
        REAL_ROOT / "drivers" / "aqara-cube-t1-pro" / "aqara-cube-t1-pro.groovy", cube
    )

    result = runner.invoke(app, ["bump", "aqara-cube-t1-pro", "3.3.1"])
    assert result.exit_code == 0, result.output
    assert (
        manifests.driver_identity(cube / "aqara-cube-t1-pro.groovy").version == "3.3.1"
    )

    result = runner.invoke(app, ["check", str(cube / "aqara-cube-t1-pro.groovy")])
    assert result.exit_code == 0, result.output
