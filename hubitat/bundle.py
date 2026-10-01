"""Generate ``<driver>.bundled.groovy`` from a driver source and its ``rbn.*`` libraries.

Hubitat imports a single file. The authored driver source uses ``#include rbn.<name>``
lines; this module inlines each ``hubitat/libraries/<name>.groovy`` after the source in
include order, reproducing the upstream marker format so that a hub compile error on a
bundle line maps back to a library line via its trailing ``// library marker`` comment.

Every ``#include`` line becomes an empty line, so driver-body line numbers are identical
in source and bundle. The ``Libraries`` banner is emitted once, after the source, unless the
source already ends with it (upstream-derived drivers do).
"""

from __future__ import annotations

import re
from pathlib import Path

import hubitat

NAMESPACE = "rbn"
BANNER = (
    "// /////////////////////////////////////////////////////////////////// "
    "Libraries "
    "//////////////////////////////////////////////////////////////////////"
)
INCLUDE = re.compile(rf"^#include\s+{NAMESPACE}\.([A-Za-z0-9_.\-]+)\s*$")
MARKER = re.compile(rf" // library marker {NAMESPACE}\.([A-Za-z0-9_.\-]+), line (\d+)$")
TRIPLE_QUOTES = ("'''", '"""')


class BundleError(Exception):
    """A driver or library that cannot be bundled faithfully."""


def library_lines(name: str) -> list[str]:
    path = hubitat.LIBRARIES / f"{name}.groovy"
    if not path.is_file():
        raise BundleError(f"library '{name}' not found at {path}")
    text = path.read_text(encoding="utf-8")
    for quote in TRIPLE_QUOTES:
        if quote in text:
            raise BundleError(
                f"library '{name}' contains a {quote} string literal; "
                "a per-line marker comment would corrupt it"
            )
    lines = text.splitlines()
    for number, line in enumerate(lines, start=1):
        if line.startswith("#include"):
            raise BundleError(
                f"library '{name}' has a nested #include at line {number}; "
                "libraries must not include libraries"
            )
    return lines


def bundle(source: Path) -> str:
    out: list[str] = []
    names: list[str] = []
    for line in source.read_text(encoding="utf-8").splitlines():
        match = INCLUDE.match(line)
        if match:
            names.append(match.group(1))
            out.append("")
        elif line.startswith("#include"):
            raise BundleError(f"{source}: include is not {NAMESPACE}.*: {line!r}")
        else:
            out.append(line)
    if not names:
        raise BundleError(f"{source}: no '#include {NAMESPACE}.<name>' lines")

    # Upstream-derived sources often end with the banner already; don't double it.
    if out[-1] != BANNER:
        out.append(BANNER)
    for name in names:
        out.append("")
        out.append(f"// ~~~~~ start include {NAMESPACE}.{name} ~~~~~")
        out.extend(
            f"{line} // library marker {NAMESPACE}.{name}, line {number}"
            for number, line in enumerate(library_lines(name), start=1)
        )
        out.append(f"// ~~~~~ end include {NAMESPACE}.{name} ~~~~~")
    return "\n".join(out) + "\n"


def bundle_path(source: Path) -> Path:
    return source.with_name(f"{source.stem}.bundled.groovy")


def driver_sources() -> list[Path]:
    return sorted(
        p
        for p in hubitat.DRIVERS.glob("*/*.groovy")
        if not p.name.endswith(".bundled.groovy")
    )


def is_stale(source: Path) -> bool:
    target = bundle_path(source)
    current = target.read_text(encoding="utf-8") if target.is_file() else None
    return current != bundle(source)


def write(source: Path) -> Path:
    target = bundle_path(source)
    target.write_text(bundle(source), encoding="utf-8")
    return target


def resolve_line(bundled: str, line: int) -> tuple[str, int] | None:
    """Map a 1-based bundle line to ``(library name, library line)`` via its marker.

    Returns ``None`` for lines that belong to the driver body rather than a library.
    """
    lines = bundled.splitlines()
    if not 1 <= line <= len(lines):
        return None
    match = MARKER.search(lines[line - 1])
    if not match:
        return None
    return match.group(1), int(match.group(2))
