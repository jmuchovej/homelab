"""Hubitat Package Manager files and their agreement with the driver sources.

HPM's update detection is the manifest ``version`` string alone and its install input is
the bundle at ``drivers[].location``; neither is checked by HPM against the driver, so
``check`` does it here. ``packageManifest.json`` sits beside each driver source and
``repository.json`` at the package root lists every manifest.
"""

from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path
from typing import NamedTuple
from uuid import UUID

from pydantic import BaseModel, ConfigDict, HttpUrl, ValidationError

import hubitat

NAMESPACE = "rbn"
MANIFEST_NAME = "packageManifest.json"
REPOSITORY_NAME = "repository.json"
URL_MARKER = "/hubitat/"

VERSION = re.compile(
    r'^static String version\(\)\s*\{\s*"([^"]*)"\s*\}\s*$', re.MULTILINE
)
TIMESTAMP = re.compile(
    r'^static String timeStamp\(\)\s*\{\s*"([^"]*)"\s*\}\s*$', re.MULTILINE
)
DEFINITION = re.compile(r"^\s*definition\s*\((?P<args>[^{]*)\{", re.MULTILINE)
LIBRARY = re.compile(r"^\s*library\s*\((?P<args>[^)]*)\)", re.MULTILINE)


class Problem(NamedTuple):
    path: Path
    reason: str

    def __str__(self) -> str:
        return f"{self.path}: {self.reason}"


class IdentityError(Exception):
    """A driver source whose name, namespace, or version cannot be read unambiguously."""


class DriverIdentity(NamedTuple):
    name: str
    namespace: str
    version: str


LibraryIdentity = DriverIdentity


class _Model(BaseModel):
    # HPM has more keys than are validated here (apps, bundles, files, betaLocation, …);
    # keep them so a manifest round-trips through `bump` unchanged.
    model_config = ConfigDict(extra="allow")


class ManifestDriver(_Model):
    id: UUID
    name: str
    namespace: str
    location: HttpUrl
    required: bool = True


class PackageManifest(_Model):
    packageName: str
    author: str
    version: str
    minimumHEVersion: str
    dateReleased: date
    releaseNotes: str | None = None
    documentationLink: str | None = None
    drivers: list[ManifestDriver]


class RepositoryPackage(_Model):
    id: UUID
    name: str
    category: str
    location: HttpUrl
    description: str
    tags: list[str] = []


class Repository(_Model):
    author: str
    gitHubUrl: str | None = None
    payPalUrl: str | None = None
    packages: list[RepositoryPackage]


def manifest_path(source: Path) -> Path:
    return source.parent / MANIFEST_NAME


def repository_path() -> Path:
    return hubitat.ROOT / REPOSITORY_NAME


def manifest_paths() -> list[Path]:
    return sorted(hubitat.DRIVERS.glob(f"*/{MANIFEST_NAME}"))


def load_manifest(path: Path) -> PackageManifest:
    return PackageManifest.model_validate_json(path.read_text(encoding="utf-8"))


def dump_manifest(path: Path, manifest: PackageManifest) -> None:
    data = manifest.model_dump(mode="json", exclude_unset=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def local_path(url: str) -> Path | None:
    """The file under ``hubitat/`` that a raw-GitHub URL on ``main`` publishes."""
    if URL_MARKER not in url:
        return None
    return hubitat.ROOT / url.split(URL_MARKER, 1)[1]


def _single(pattern: re.Pattern[str], text: str, what: str, source: Path) -> str:
    found = pattern.findall(text)
    if len(found) != 1:
        raise IdentityError(
            f"{source}: expected exactly one {what}, found {len(found)}"
        )
    return found[0]


def _argument(key: str, args: str, source: Path) -> str:
    match = re.search(rf"\b{key}\s*:\s*(['\"])(.*?)\1", args)
    if not match:
        raise IdentityError(f"{source}: no {key}: in the definition()/library() header")
    return match.group(2)


def driver_identity(source: Path) -> DriverIdentity:
    text = source.read_text(encoding="utf-8")
    version = _single(VERSION, text, "'static String version()' line", source)
    args = _single(DEFINITION, text, "definition(", source)
    return DriverIdentity(
        name=_argument("name", args, source),
        namespace=_argument("namespace", args, source),
        version=version,
    )


def library_identity(source: Path) -> LibraryIdentity:
    """Name, namespace, and version from a library's ``library(...)`` header."""
    text = source.read_text(encoding="utf-8")
    args = _single(LIBRARY, text, "library(", source)
    return LibraryIdentity(
        name=_argument("name", args, source),
        namespace=_argument("namespace", args, source),
        version=_argument("version", args, source),
    )


def _summary(error: ValidationError) -> str:
    return "; ".join(
        f"{'.'.join(str(part) for part in item['loc'])}: {item['msg']}"
        for item in error.errors()
    )


def check_manifest(source: Path, *, required: bool = False) -> list[Problem]:
    """Problems with the manifest beside ``source``; empty when absent and not required."""
    path = manifest_path(source)
    if not path.is_file():
        return [Problem(path, "missing")] if required else []
    try:
        manifest = load_manifest(path)
    except ValidationError as error:
        return [Problem(path, _summary(error))]
    try:
        identity = driver_identity(source)
    except IdentityError as error:
        return [Problem(source, str(error))]

    problems: list[Problem] = []
    if manifest.version != identity.version:
        problems.append(
            Problem(
                path,
                f"version {manifest.version!r} != driver version() {identity.version!r}",
            )
        )
    if len(manifest.drivers) != 1:
        problems.append(
            Problem(
                path,
                f"expected exactly one drivers[] entry, found {len(manifest.drivers)}",
            )
        )
        return problems
    driver = manifest.drivers[0]
    if driver.namespace != NAMESPACE:
        problems.append(
            Problem(path, f"driver namespace {driver.namespace!r} != {NAMESPACE!r}")
        )
    if driver.name != identity.name:
        problems.append(
            Problem(path, f"driver name {driver.name!r} != {identity.name!r}")
        )
    expected = f"{URL_MARKER}drivers/{source.parent.name}/{source.stem}.bundled.groovy"
    if not str(driver.location).endswith(expected):
        problems.append(Problem(path, f"driver location does not end in {expected}"))
    return problems


def check_repository() -> list[Problem]:
    """Problems with ``repository.json``; empty when it does not exist."""
    path = repository_path()
    if not path.is_file():
        return []
    try:
        repository = Repository.model_validate_json(path.read_text(encoding="utf-8"))
    except ValidationError as error:
        return [Problem(path, _summary(error))]

    problems: list[Problem] = []
    indexed: set[Path] = set()
    for package in repository.packages:
        local = local_path(str(package.location))
        if local is None:
            problems.append(
                Problem(
                    path, f"package {package.name!r}: location is not under hubitat/"
                )
            )
        elif not local.is_file():
            problems.append(
                Problem(path, f"package {package.name!r}: no manifest at {local}")
            )
        else:
            indexed.add(local.resolve())
    for manifest in manifest_paths():
        if manifest.resolve() not in indexed:
            problems.append(Problem(manifest, f"not listed in {REPOSITORY_NAME}"))
    return problems
