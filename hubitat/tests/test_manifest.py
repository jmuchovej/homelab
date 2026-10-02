from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from hubitat import manifest as manifests

DRIVER_ID = "4f1c0e3a-6d4b-4a7a-9d1e-0f2b3c4d5e6f"
PACKAGE_ID = "9b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d"
BUNDLE_URL = "https://raw.githubusercontent.com/o/r/main/hubitat/drivers/probe/probe.bundled.groovy"
MANIFEST_URL = "https://raw.githubusercontent.com/o/r/main/hubitat/drivers/probe/packageManifest.json"


def probe(tree: Path) -> Path:
    return tree / "drivers" / "probe" / "probe.groovy"


def manifest_dict(**driver: Any) -> dict[str, Any]:
    entry = {
        "id": DRIVER_ID,
        "name": "Probe Driver",
        "namespace": "rbn",
        "location": BUNDLE_URL,
        "required": True,
    }
    entry.update(driver)
    return {
        "packageName": "Probe Driver",
        "author": "test",
        "version": "1.2.3",
        "minimumHEVersion": "2.3.0",
        "dateReleased": "2026-10-01",
        "releaseNotes": "first",
        "drivers": [entry],
    }


def write_manifest(tree: Path, data: dict[str, Any]) -> Path:
    path = manifests.manifest_path(probe(tree))
    path.write_text(json.dumps(data))
    return path


def write_repository(tree: Path, location: str = MANIFEST_URL) -> Path:
    path = tree / "repository.json"
    path.write_text(
        json.dumps(
            {
                "author": "test",
                "gitHubUrl": "https://github.com/o/r",
                "packages": [
                    {
                        "id": PACKAGE_ID,
                        "name": "Probe Driver",
                        "category": "Control",
                        "location": location,
                        "description": "probe",
                        "tags": ["Zigbee"],
                    }
                ],
            }
        )
    )
    return path


def test_driver_identity_reads_multiline_definition(tree: Path) -> None:
    path = probe(tree)
    path.write_text(
        path.read_text().replace(
            "definition(name: 'Probe Driver', namespace: 'rbn', author: 'test') {",
            "definition (\n        name: 'Probe Driver',\n        importUrl: 'x',\n"
            "        namespace: 'rbn', author: 'test', singleThreaded: true ) {",
        )
    )
    assert manifests.driver_identity(path) == ("Probe Driver", "rbn", "1.2.3")


def test_agreement_passes(tree: Path) -> None:
    write_manifest(tree, manifest_dict())
    assert manifests.check_manifest(probe(tree)) == []


def test_missing_manifest(tree: Path) -> None:
    assert manifests.check_manifest(probe(tree)) == []
    problems = manifests.check_manifest(probe(tree), required=True)
    assert len(problems) == 1
    assert problems[0].path == manifests.manifest_path(probe(tree))


def test_version_drift(tree: Path) -> None:
    data = manifest_dict()
    data["version"] = "1.2.4"
    path = write_manifest(tree, data)
    problems = manifests.check_manifest(probe(tree))
    assert len(problems) == 1
    assert problems[0].path == path
    assert "1.2.4" in problems[0].reason and "1.2.3" in problems[0].reason


def test_wrong_location(tree: Path) -> None:
    path = write_manifest(
        tree, manifest_dict(location=BUNDLE_URL.replace("probe.bundled", "probe"))
    )
    problems = manifests.check_manifest(probe(tree))
    assert [p.path for p in problems] == [path]
    assert "location" in problems[0].reason


def test_wrong_name(tree: Path) -> None:
    path = write_manifest(tree, manifest_dict(name="Other Driver"))
    problems = manifests.check_manifest(probe(tree))
    assert [p.path for p in problems] == [path]
    assert "name" in problems[0].reason


def test_wrong_namespace(tree: Path) -> None:
    path = write_manifest(tree, manifest_dict(namespace="kkossev"))
    problems = manifests.check_manifest(probe(tree))
    assert [p.path for p in problems] == [path]
    assert "namespace" in problems[0].reason


def test_non_uuid_id(tree: Path) -> None:
    path = write_manifest(tree, manifest_dict(id="not-a-uuid"))
    problems = manifests.check_manifest(probe(tree))
    assert [p.path for p in problems] == [path]
    assert "drivers.0.id" in problems[0].reason


def test_two_drivers(tree: Path) -> None:
    data = manifest_dict()
    data["drivers"].append(dict(data["drivers"][0]))
    path = write_manifest(tree, data)
    problems = manifests.check_manifest(probe(tree))
    assert [p.path for p in problems] == [path]
    assert "exactly one" in problems[0].reason


def test_repository_agreement(tree: Path) -> None:
    write_manifest(tree, manifest_dict())
    write_repository(tree)
    assert manifests.check_repository() == []


def test_repository_absent_is_fine(tree: Path) -> None:
    write_manifest(tree, manifest_dict())
    assert manifests.check_repository() == []


def test_dangling_index_entry(tree: Path) -> None:
    path = write_repository(tree, MANIFEST_URL.replace("probe", "ghost"))
    problems = manifests.check_repository()
    assert [p.path for p in problems] == [path]
    assert "ghost" in problems[0].reason


def test_repository_requires_category_and_tags(tree: Path) -> None:
    write_manifest(tree, manifest_dict())
    path = write_repository(tree)
    data = json.loads(path.read_text())
    data["packages"][0]["tags"] = []
    path.write_text(json.dumps(data))
    problems = manifests.check_repository()
    assert [p.path for p in problems] == [path]
    assert "category and tags" in problems[0].reason


def test_unindexed_manifest(tree: Path) -> None:
    manifest = write_manifest(tree, manifest_dict())
    write_repository(tree, MANIFEST_URL.replace("probe", "other"))
    other = tree / "drivers" / "other"
    other.mkdir()
    (other / "packageManifest.json").write_text("{}")
    problems = manifests.check_repository()
    assert [p.path for p in problems] == [manifest]
    assert "not listed" in problems[0].reason


def test_dump_round_trips_unknown_keys(tree: Path) -> None:
    data = manifest_dict()
    data["betaLocation"] = "https://example.invalid/beta"
    path = write_manifest(tree, data)
    loaded = manifests.load_manifest(path)
    loaded.version = "1.2.4"
    manifests.dump_manifest(path, loaded)
    written = json.loads(path.read_text())
    assert written["version"] == "1.2.4"
    assert written["betaLocation"] == data["betaLocation"]
    assert written["dateReleased"] == "2026-10-01"
    assert "documentationLink" not in written
