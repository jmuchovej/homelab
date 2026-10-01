"""Change a driver's version everywhere that must agree: ``version()``, ``timeStamp()``,
the sibling HPM manifest when there is one, and the regenerated bundle.

Text edits with anchored regexes, not an AST: both lines are single-line conventions the
tree already requires, and the edit refuses when either is missing or duplicated.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from . import bundle as bundling
from . import manifest as manifests


class BumpError(Exception):
    """A driver whose version lines cannot be rewritten unambiguously."""


def bump(source: Path, version: str, when: datetime | None = None) -> list[Path]:
    """Rewrite the version in ``source`` and its siblings; returns every file written."""
    when = when or datetime.now().astimezone()
    text = source.read_text(encoding="utf-8")
    text, hits = manifests.VERSION.subn(
        lambda _: f'static String version() {{ "{version}" }}', text
    )
    if hits != 1:
        raise BumpError(
            f"{source}: expected exactly one 'static String version()' line, found {hits}"
        )
    stamp = when.strftime("%Y/%m/%d %I:%M %p")
    text, hits = manifests.TIMESTAMP.subn(
        lambda _: f'static String timeStamp() {{"{stamp}"}}', text
    )
    if hits != 1:
        raise BumpError(
            f"{source}: expected exactly one 'static String timeStamp()' line, found {hits}"
        )
    source.write_text(text, encoding="utf-8")
    written = [source]

    manifest_path = manifests.manifest_path(source)
    if manifest_path.is_file():
        manifest = manifests.load_manifest(manifest_path)
        manifest.version = version
        manifest.dateReleased = when.date()
        manifests.dump_manifest(manifest_path, manifest)
        written.append(manifest_path)

    written.append(bundling.write(source))
    return written
