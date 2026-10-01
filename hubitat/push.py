"""Create or update ``rbn`` drivers on the hub from their committed bundles, idempotently.

A driver is matched by ``(name, namespace)`` from the hub's user driver list; the
namespace is read from the source and must be ``rbn``, so code in any other namespace is
never touched even when the name collides. An existing driver is updated only when the
hub's current source differs from the bundle, with the ``version`` read moments before.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from . import bundle as bundling
from . import manifest as manifests
from .hub import Hub, HubDriver

NAMESPACE = "rbn"
Kind = Literal["created", "updated", "unchanged"]


class PushError(Exception):
    """A source that cannot be pushed as it stands."""


@dataclass(frozen=True)
class Action:
    source: Path
    name: str
    kind: Kind
    text: str
    existing: HubDriver | None = None
    version: object = None

    def describe(self, *, dry_run: bool) -> str:
        verb = {"created": "create", "updated": "update", "unchanged": "unchanged"}[
            self.kind
        ]
        if self.kind == "unchanged":
            return f"unchanged  {self.name}"
        if dry_run:
            return f"would {verb}  {self.name}"
        return f"{self.kind}  {self.name}"


def _normalise(text: str) -> str:
    return text.replace("\r\n", "\n").rstrip("\n")


def _same(hub_source: str, bundled: str) -> bool:
    return _normalise(hub_source) == _normalise(bundled)


def plan(hub: Hub, sources: list[Path]) -> list[Action]:
    on_hub = {(driver.name, driver.namespace): driver for driver in hub.drivers()}
    actions: list[Action] = []
    for source in sources:
        identity = manifests.driver_identity(source)
        if identity.namespace != NAMESPACE:
            raise PushError(
                f"{source}: namespace {identity.namespace!r} is not {NAMESPACE!r}"
            )
        if bundling.is_stale(source):
            raise PushError(f"{source}: bundle is stale; run `bundle` first")
        text = bundling.bundle_path(source).read_text(encoding="utf-8")
        existing = on_hub.get((identity.name, NAMESPACE))
        if existing is None:
            actions.append(Action(source, identity.name, "created", text))
            continue
        code = hub.driver_code(existing.id)
        kind: Kind = "unchanged" if _same(code.source, text) else "updated"
        actions.append(
            Action(source, identity.name, kind, text, existing, code.version)
        )
    return actions


def apply(hub: Hub, actions: list[Action]) -> list[int]:
    """Perform the writes; returns the hub id of every driver the actions refer to."""
    ids: list[int] = []
    for action in actions:
        if action.kind == "created":
            ids.append(hub.create_driver(action.text))
        else:
            assert action.existing is not None
            ids.append(action.existing.id)
            if action.kind == "updated":
                hub.update_driver(action.existing.id, action.version, action.text)
    return ids
