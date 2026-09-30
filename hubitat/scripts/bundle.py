"""Generate ``<driver>.bundled.groovy`` from a driver source and its ``rbn.*`` libraries.

Hubitat imports a single file. The authored driver source uses ``#include rbn.<name>``
lines; this script inlines each ``hubitat/libraries/<name>.groovy`` after the source in
include order, reproducing the upstream marker format so that a hub compile error on a
bundle line maps back to a library line via its trailing ``// library marker`` comment.

Every ``#include`` line becomes an empty line, so driver-body line numbers are identical
in source and bundle. The ``Libraries`` banner is emitted once, after the source, unless the
source already ends with it (upstream-derived drivers do).

Usage::

    bundle.py [--check] [SOURCE ...]

With no SOURCE, every ``hubitat/drivers/*/*.groovy`` that does not end in
``.bundled.groovy`` is processed. ``--check`` writes nothing and exits 1 if any bundle on
disk differs from what would be generated.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HUBITAT = Path(__file__).resolve().parent.parent
LIBRARIES = HUBITAT / "libraries"
DRIVERS = HUBITAT / "drivers"
NAMESPACE = "rbn"
BANNER = (
    "// /////////////////////////////////////////////////////////////////// "
    "Libraries "
    "//////////////////////////////////////////////////////////////////////"
)
INCLUDE = re.compile(rf"^#include\s+{NAMESPACE}\.([A-Za-z0-9_.\-]+)\s*$")
TRIPLE_QUOTES = ("'''", '"""')


class BundleError(Exception):
    """A driver or library that cannot be bundled faithfully."""


def library_lines(name: str) -> list[str]:
    path = LIBRARIES / f"{name}.groovy"
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


def default_sources() -> list[Path]:
    return sorted(
        p for p in DRIVERS.glob("*/*.groovy") if not p.name.endswith(".bundled.groovy")
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("sources", nargs="*", type=Path, help="driver source files")
    parser.add_argument(
        "--check",
        action="store_true",
        help="write nothing; exit 1 if any bundle on disk is stale",
    )
    args = parser.parse_args(argv)

    sources = [p.resolve() for p in args.sources] or default_sources()
    if not sources:
        print(f"no driver sources under {DRIVERS}", file=sys.stderr)
        return 1

    failed = False
    for source in sources:
        target = bundle_path(source)
        try:
            generated = bundle(source)
        except BundleError as error:
            print(f"error: {error}", file=sys.stderr)
            failed = True
            continue
        if args.check:
            current = target.read_text(encoding="utf-8") if target.is_file() else None
            if current != generated:
                print(f"stale: {target}", file=sys.stderr)
                failed = True
            continue
        target.write_text(generated, encoding="utf-8")
        print(f"wrote {target}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
