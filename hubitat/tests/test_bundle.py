from __future__ import annotations

from pathlib import Path

import pytest
from typer.testing import CliRunner

from hubitat import bundle as bundling
from hubitat.cli import app

runner = CliRunner()


def probe(tree: Path) -> Path:
    return tree / "drivers" / "probe" / "probe.groovy"


def test_driver_lines_keep_their_numbers(tree: Path) -> None:
    source_lines = probe(tree).read_text().splitlines()
    out = bundling.bundle(probe(tree)).splitlines()
    assert source_lines[4] == "metadata {"
    assert out[4] == "metadata {"
    # the #include line becomes a one-line pointer, so nothing below it moves
    assert out[1].startswith("// #include rbn.tiny  -- included at line ")


def test_include_comments_name_each_start_marker_line(tree: Path) -> None:
    (tree / "libraries" / "second.groovy").write_text(
        "library(name: 'second', namespace: 'rbn', version: '0.0.1')\n"
        "def a() { }\ndef b() { }\ndef c() { }\n"
    )
    path = probe(tree)
    path.write_text(
        path.read_text().replace(
            "#include rbn.tiny\n", "#include rbn.tiny\n#include rbn.second\n"
        )
    )
    out = bundling.bundle(path).splitlines()
    for index, name in ((1, "tiny"), (2, "second")):
        prefix = f"// #include rbn.{name}  -- included at line "
        assert out[index].startswith(prefix)
        line = int(out[index].removeprefix(prefix))
        assert out[line - 1] == f"// ~~~~~ start include rbn.{name} ~~~~~"


def test_banner_emitted_once_when_source_lacks_it(tree: Path) -> None:
    out = bundling.bundle(probe(tree))
    assert out.count(bundling.BANNER) == 1


def test_banner_not_duplicated_when_source_ends_with_it(tree: Path) -> None:
    path = probe(tree)
    path.write_text(path.read_text() + bundling.BANNER + "\n")
    out = bundling.bundle(path)
    assert out.count(bundling.BANNER) == 1


def test_library_lines_carry_source_line_markers(tree: Path) -> None:
    out = bundling.bundle(probe(tree)).splitlines()
    start = out.index("// ~~~~~ start include rbn.tiny ~~~~~")
    assert out[start + 1].endswith(" // rbn.tiny#L1")
    assert out[start + 2].endswith(" // rbn.tiny#L2")
    assert out[start + 3] == "// ~~~~~ end include rbn.tiny ~~~~~"
    assert bundling.resolve_line("\n".join(out), start + 3) == ("tiny", 2)
    assert bundling.resolve_line("\n".join(out), 5) is None


HEADERED_LIBRARY = """\
/* groovylint-disable LineLength */
library(
    name: 'tiny', namespace: 'rbn', version: '0.0.1'
)
/*
 *  Tiny Library
 *
 *  Licensed Virtual the Apache License, Version 2.0
 *
 * ver. 0.0.1  2026-01-01 someone  - first
 *
 *                                   TODO: nothing
*/

static String tinyVersion() { '0.0.1' }  // trailing comment goes

// a comment-only line goes
/* so does
   a block comment */
metadata {
    attribute 'url', 'string'   // keep the value: 'https://x/y'
    input title: 'A /* not a comment */ B'
}


def ratio() { return 1/*0*/ * 2 }
"""


def test_library_block_keeps_code_and_notice_only(tree: Path) -> None:
    (tree / "libraries" / "tiny.groovy").write_text(HEADERED_LIBRARY)
    out = bundling.bundle(probe(tree))
    start = out.index("// ~~~~~ start include rbn.tiny ~~~~~")
    block = out[start:].splitlines()
    assert block[1:] == [
        "library( // rbn.tiny#L2",
        "    name: 'tiny', namespace: 'rbn', version: '0.0.1' // rbn.tiny#L3",
        ") // rbn.tiny#L4",
        "/*",
        " *  Tiny Library",
        " *",
        " *  Licensed Virtual the Apache License, Version 2.0",
        " *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/tiny.groovy#L10-L12",
        "*/",
        "",
        "static String tinyVersion() { '0.0.1' } // rbn.tiny#L15",
        "",
        "metadata { // rbn.tiny#L20",
        "    attribute 'url', 'string' // rbn.tiny#L21",
        "    input title: 'A /* not a comment */ B' // rbn.tiny#L22",
        "} // rbn.tiny#L23",
        "",
        "def ratio() { return 1  * 2 } // rbn.tiny#L26",
        "// ~~~~~ end include rbn.tiny ~~~~~",
    ]
    assert "groovylint-disable" not in out
    start_line = out[:start].count("\n") + 1
    marker_line = start_line + block.index("} // rbn.tiny#L23")
    assert bundling.resolve_line(out, marker_line) == ("tiny", 23)


def test_strip_comments_keeps_a_line_it_cannot_scan() -> None:
    assert bundling.strip_comments(["x = 'open // not closed"]) == [
        "x = 'open // not closed"
    ]
    assert bundling.strip_comments(['s = "a\\"b" // gone', "/* a", "b */ c // d"]) == [
        's = "a\\"b"',
        "",
        "  c",
    ]


def test_missing_library_is_refused(tree: Path) -> None:
    path = probe(tree)
    path.write_text(path.read_text().replace("rbn.tiny", "rbn.absent"))
    with pytest.raises(bundling.BundleError, match="'absent'"):
        bundling.bundle(path)


def test_nested_include_is_refused(tree: Path) -> None:
    library = tree / "libraries" / "tiny.groovy"
    library.write_text(library.read_text() + "#include rbn.other\n")
    with pytest.raises(bundling.BundleError, match="'tiny'.*nested #include at line 3"):
        bundling.bundle(probe(tree))


def test_triple_quoted_string_is_refused(tree: Path) -> None:
    library = tree / "libraries" / "tiny.groovy"
    library.write_text(library.read_text() + 'def s = """x"""\n')
    with pytest.raises(bundling.BundleError, match="'tiny'.*string literal"):
        bundling.bundle(probe(tree))


def test_source_without_includes_is_refused(tree: Path) -> None:
    path = probe(tree)
    path.write_text(path.read_text().replace("#include rbn.tiny\n", "\n"))
    with pytest.raises(bundling.BundleError, match="no '#include rbn"):
        bundling.bundle(path)


def test_check_requires_a_manifest(tree: Path) -> None:
    bundling.write(probe(tree))
    result = runner.invoke(app, ["check"])
    assert result.exit_code == 1
    assert "packageManifest.json: missing" in result.output


def test_check_reports_stale_then_fresh(tree: Path) -> None:
    from test_manifest import manifest_dict, write_manifest, write_repository

    write_manifest(tree, manifest_dict())
    write_repository(tree)
    target = bundling.bundle_path(probe(tree))

    result = runner.invoke(app, ["check"])
    assert result.exit_code == 1
    assert f"stale: {target}" in result.output

    result = runner.invoke(app, ["bundle"])
    assert result.exit_code == 0
    assert target.read_text() == bundling.bundle(probe(tree))

    result = runner.invoke(app, ["check"])
    assert result.exit_code == 0

    target.write_text(target.read_text() + "// drift\n")
    result = runner.invoke(app, ["check"])
    assert result.exit_code == 1


def test_check_names_bundle_errors(tree: Path) -> None:
    path = probe(tree)
    path.write_text(path.read_text().replace("rbn.tiny", "rbn.absent"))
    result = runner.invoke(app, ["check"])
    assert result.exit_code == 1
    assert "error: library 'absent' not found" in result.output
