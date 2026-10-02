"""Create or update ``rbn`` code on the hub from the repo, idempotently.

Drivers and libraries are pushed from their sources: the hub stores a driver's ``#include``
lines verbatim and resolves them against its Libraries Code at compile time, so a driver
push is preceded by the libraries it includes. The committed bundle is the distribution
form for other hubs; only ``probe`` pushes bundles, which is how they get compile-checked.

Either kind is matched by ``(name, namespace)`` from the hub's user code list; the
namespace is read from the source and must be ``rbn``, so code in any other namespace is
never touched even when the name collides. Existing code is updated only when the hub's
current source differs, with the ``version`` read moments before.
"""

from __future__ import annotations

import re
import tempfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import hubitat

from . import bundle as bundling
from . import manifest as manifests
from .hub import DriverCode, Hub, HubDriver, HubError

NAMESPACE = "rbn"
PROBE_NAME = "rbn include-all probe"
LINE_NUMBER = re.compile(r"\bline (\d+)\b")
Kind = Literal["created", "updated", "unchanged"]
Code = Literal["driver", "library"]


class PushError(Exception):
    """A source that cannot be pushed as it stands."""


class ProbeError(Exception):
    """The include-all probe failed to compile on the hub (message carries the hub's text)."""


@dataclass(frozen=True)
class Action:
    source: Path
    name: str
    kind: Kind
    text: str
    existing: HubDriver | None = None
    version: object = None
    code: Code = "driver"

    def describe(self, *, dry_run: bool) -> str:
        label = f"{self.name}" if self.code == "driver" else f"library {self.name}"
        verb = {"created": "create", "updated": "update", "unchanged": "unchanged"}[
            self.kind
        ]
        if self.kind == "unchanged":
            return f"unchanged  {label}"
        if dry_run:
            return f"would {verb}  {label}"
        return f"{self.kind}  {label}"


def _normalise(text: str) -> str:
    return text.replace("\r\n", "\n").rstrip("\n")


def _same(hub_source: str, bundled: str) -> bool:
    return _normalise(hub_source) == _normalise(bundled)


def _source_text(source: Path) -> str:
    return source.read_text(encoding="utf-8")


def _bundle_text(source: Path) -> str:
    if bundling.is_stale(source):
        raise PushError(f"{source}: bundle is stale; run `bundle` first")
    return bundling.bundle_path(source).read_text(encoding="utf-8")


def _plan(
    sources: list[Path],
    *,
    code: Code,
    on_hub: list[HubDriver],
    identity: Callable[[Path], manifests.DriverIdentity],
    text: Callable[[Path], str],
    read: Callable[[int], DriverCode],
) -> list[Action]:
    by_key = {(item.name, item.namespace): item for item in on_hub}
    actions: list[Action] = []
    for source in sources:
        ident = identity(source)
        if ident.namespace != NAMESPACE:
            raise PushError(
                f"{source}: namespace {ident.namespace!r} is not {NAMESPACE!r}"
            )
        body = text(source)
        existing = by_key.get((ident.name, NAMESPACE))
        if existing is None:
            actions.append(Action(source, ident.name, "created", body, code=code))
            continue
        current = read(existing.id)
        kind: Kind = "unchanged" if _same(current.source, body) else "updated"
        actions.append(
            Action(source, ident.name, kind, body, existing, current.version, code)
        )
    return actions


def plan_libraries(hub: Hub, sources: list[Path]) -> list[Action]:
    """Actions for library sources, pushed verbatim."""
    return _plan(
        sources,
        code="library",
        on_hub=hub.libraries(),
        identity=manifests.library_identity,
        text=_source_text,
        read=hub.library_code,
    )


def plan(hub: Hub, sources: list[Path], *, bundled: bool = False) -> list[Action]:
    """Actions for drivers: the libraries they include, then the sources themselves.

    With ``bundled``, the committed bundles alone — self-contained, so no library actions.
    """
    actions: list[Action] = []
    if not bundled:
        names = dict.fromkeys(
            name for s in sources for name in bundling.include_names(s)
        )
        libraries = [hubitat.LIBRARIES / f"{name}.groovy" for name in names]
        for library in libraries:
            if not library.is_file():
                raise PushError(f"included library not found at {library}")
        actions.extend(plan_libraries(hub, libraries))
    actions.extend(
        _plan(
            sources,
            code="driver",
            on_hub=hub.drivers(),
            identity=manifests.driver_identity,
            text=_bundle_text if bundled else _source_text,
            read=hub.driver_code,
        )
    )
    return actions


def apply(hub: Hub, actions: list[Action]) -> list[int]:
    """Perform the writes; returns the hub id of every item the actions refer to."""
    ids: list[int] = []
    for action in actions:
        create = hub.create_driver if action.code == "driver" else hub.create_library
        update = hub.update_driver if action.code == "driver" else hub.update_library
        if action.kind == "created":
            ids.append(create(action.text))
        else:
            assert action.existing is not None
            ids.append(action.existing.id)
            if action.kind == "updated":
                update(action.existing.id, action.version, action.text)
    return ids


def library_sources() -> list[Path]:
    return sorted(hubitat.LIBRARIES.glob("*.groovy"))


def library_names() -> list[str]:
    return [path.stem for path in library_sources()]


def probe_source(names: list[str]) -> str:
    """A driver that does nothing but include every library, so the hub compiles them all."""
    lines = [
        "/* Generated by `hubitat probe`; pushed to the hub and deleted, never committed. */",
        "import groovy.transform.Field",
        "",
        'static String version() { "0.0.0" }',
        'static String timeStamp() {"1970/01/01 12:00 AM"}',
        "",
        'deviceType = "Probe"',
        '@Field static final String DEVICE_TYPE = "Probe"',
        "",
        "metadata {",
        f"    definition(name: '{PROBE_NAME}', namespace: '{NAMESPACE}', author: 'probe') {{",
        "        capability 'Sensor'",
        "    }",
        "}",
        "",
        *(f"#include {NAMESPACE}.{name}" for name in names),
    ]
    return "\n".join(lines) + "\n"


def resolve_error(message: str, bundled: str) -> str:
    """Append ``<library>.groovy:<line>`` for every bundle line number the hub mentions."""
    resolved = []
    for match in LINE_NUMBER.finditer(message):
        hit = bundling.resolve_line(bundled, int(match.group(1)))
        if hit:
            resolved.append(f"{hit[0]}.groovy:{hit[1]}")
    if not resolved:
        return message
    return f"{message}\n  -> {', '.join(dict.fromkeys(resolved))}"


def probe(hub: Hub) -> list[str]:
    """Compile every library's bundled form on the hub via a throwaway driver.

    Pushed as a bundle on purpose: this is the only compile check the stripped library
    blocks get, since our own hubs take the sources. Returns the library names.
    """
    names = library_names()
    if not names:
        raise ProbeError(f"no libraries under {hubitat.LIBRARIES}")
    with tempfile.TemporaryDirectory(prefix="hubitat-probe-") as tmp:
        source = Path(tmp) / "probe" / "probe.groovy"
        source.parent.mkdir()
        source.write_text(probe_source(names), encoding="utf-8")
        bundled = bundling.write(source).read_text(encoding="utf-8")
        ids: list[int] = []
        try:
            ids = apply(hub, plan(hub, [source], bundled=True))
        except HubError as error:
            raise ProbeError(resolve_error(str(error), bundled)) from error
        finally:
            _delete_probes(hub, ids)
    return names


def _delete_probes(hub: Hub, ids: list[int]) -> None:
    """Delete the probe by the ids we touched, then by name for any earlier run's leftovers."""
    for id in ids:
        hub.delete_driver(id)
    for driver in hub.drivers():
        if driver.name == PROBE_NAME and driver.namespace == NAMESPACE:
            hub.delete_driver(driver.id)
