"""Generate ``<driver>.bundled.groovy``: the distribution form of a driver.

Hubitat's ``#include`` is resolved by the hub against the libraries installed on it, and
the hub's Import button and HPM each fetch one file, so a driver that includes ``rbn.*``
cannot be installed on a hub that lacks them. The bundle is the self-contained copy for
that case; our own hubs take the source, with the libraries pushed first (``push``).

Shape of a bundle::

    <driver source, each "#include rbn.X" replaced by "// #include rbn.X  -- included at line N">
    <Libraries banner>

    // ~~~~~ start include rbn.X ~~~~~                 <- line N
    library(                           // rbn.X#L2
        name: 'X', namespace: 'rbn',   // rbn.X#L3
    )                                  // rbn.X#L4
    /*
     *  <notice lines of X's header comment, verbatim>
     *  Changelog: <repository URL>/blob/main/hubitat/libraries/X.groovy#La-Lb
    */
    <every remaining line of X that carries code, comments removed>  // rbn.X#L<n>
    // ~~~~~ end include rbn.X ~~~~~

The driver body keeps its line numbers (an ``#include`` line becomes one comment line).
Library lines do not: comment-only lines are dropped and trailing comments removed, and
each kept line names its source line in a ``// rbn.X#L<n>`` marker, which is what a hub
compile error on a bundle line is mapped back through (``resolve_line``). The header
comment is the one piece of each library kept as prose, because it is the licence and
attribution notice; only its changelog collapses to a pointer.
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
MARKER = re.compile(rf" // {NAMESPACE}\.([A-Za-z0-9_.\-]+)#L(\d+)$")
CHANGELOG_ENTRY = re.compile(r"^\s*\*\s*ver\.\s")
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


def strip_comments(lines: list[str]) -> list[str]:
    """Each line with its comments removed and right-stripped; comment-only lines become ``""``.

    A three-state scan (code, inside a string, inside a block comment) so that ``//`` or
    ``/*`` inside a string literal is text, and ``*/`` inside a string does not close a
    comment. A block comment becomes one space so the tokens around it cannot merge.
    A line the scan leaves inside a string is kept verbatim rather than guessed at.
    """
    out: list[str] = []
    in_block = False
    for line in lines:
        kept: list[str] = []
        quote: str | None = None
        i = 0
        while i < len(line):
            if in_block:
                if line.startswith("*/", i):
                    in_block = False
                    kept.append(" ")
                    i += 2
                else:
                    i += 1
            elif quote:
                kept.append(line[i])
                if line[i] == "\\" and i + 1 < len(line):
                    kept.append(line[i + 1])
                    i += 1
                elif line[i] == quote:
                    quote = None
                i += 1
            elif line[i] in ("'", '"'):
                quote = line[i]
                kept.append(line[i])
                i += 1
            elif line.startswith("//", i):
                break
            elif line.startswith("/*", i):
                in_block = True
                i += 2
            else:
                kept.append(line[i])
                i += 1
        out.append(line.rstrip() if quote else "".join(kept).rstrip())
    return out


def header_span(lines: list[str]) -> tuple[int, int] | None:
    """0-based ``(first, last)`` of the first block comment spanning more than one line.

    That comment is the library's licence and attribution notice (its single-line
    predecessors are lint pragmas); ``None`` when the library has no such comment.
    """
    start: int | None = None
    for index, line in enumerate(lines):
        text = line.strip()
        if start is None:
            if text.startswith("/*") and not text.endswith("*/"):
                start = index
        elif text.endswith("*/"):
            return start, index
    return None


def notice(name: str, lines: list[str], span: tuple[int, int]) -> list[str]:
    """The header comment with its changelog (``* ver. …`` to the end) replaced by a pointer."""
    first, last = span
    block = lines[first : last + 1]
    cut = next((i for i, line in enumerate(block) if CHANGELOG_ENTRY.match(line)), None)
    if cut is None:
        return block
    kept = block[:cut]
    while kept[-1].strip() in ("*", ""):
        kept.pop()
    url = f"{hubitat.REPOSITORY}/blob/main/hubitat/libraries/{name}.groovy"
    indent = kept[-1][: len(kept[-1]) - len(kept[-1].lstrip())]
    kept.append(f"{indent}*  Changelog: {url}#L{first + cut + 1}-L{last}")
    kept.append(block[-1])
    return kept


def library_block(name: str) -> list[str]:
    lines = library_lines(name)
    span = header_span(lines)
    code = strip_comments(lines)
    body: list[str] = []
    index = 0
    while index < len(lines):
        if span and index == span[0]:
            body.extend(notice(name, lines, span))
            index = span[1] + 1
            continue
        if code[index]:
            body.append(f"{code[index]} // {NAMESPACE}.{name}#L{index + 1}")
        elif body and body[-1] != "":
            body.append("")
        index += 1
    while body and body[-1] == "":
        body.pop()
    return [
        f"// ~~~~~ start include {NAMESPACE}.{name} ~~~~~",
        *body,
        f"// ~~~~~ end include {NAMESPACE}.{name} ~~~~~",
    ]


def include_names(source: Path) -> list[str]:
    """Library names from a driver's ``#include rbn.<name>`` lines, in order."""
    names: list[str] = []
    for line in source.read_text(encoding="utf-8").splitlines():
        match = INCLUDE.match(line)
        if match:
            names.append(match.group(1))
        elif line.startswith("#include"):
            raise BundleError(f"{source}: include is not {NAMESPACE}.*: {line!r}")
    if not names:
        raise BundleError(f"{source}: no '#include {NAMESPACE}.<name>' lines")
    return names


def bundle(source: Path) -> str:
    names = include_names(source)
    blocks = {name: library_block(name) for name in names}

    # None stands in for an #include line until its target line is known.
    body: list[str | None] = [
        None if INCLUDE.match(line) else line
        for line in source.read_text(encoding="utf-8").splitlines()
    ]
    # Upstream-derived sources often end with the banner already; don't double it.
    if body[-1] != BANNER:
        body.append(BANNER)

    # Each block is preceded by one blank line; its first line is the start marker.
    starts: dict[str, int] = {}
    cursor = len(body)
    for name in names:
        starts[name] = cursor + 2
        cursor += len(blocks[name]) + 1

    out: list[str] = []
    pending = iter(names)
    for line in body:
        if line is None:
            name = next(pending)
            line = f"// #include {NAMESPACE}.{name}  -- included at line {starts[name]}"
        out.append(line)
    for name in names:
        out.append("")
        out.extend(blocks[name])
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
