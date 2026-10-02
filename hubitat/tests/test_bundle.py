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


def test_library_lines_carry_numbered_markers(tree: Path) -> None:
    out = bundling.bundle(probe(tree)).splitlines()
    start = out.index("// ~~~~~ start include rbn.tiny ~~~~~")
    assert out[start + 1].endswith(" // library marker rbn.tiny, line 1")
    assert out[start + 2].endswith(" // library marker rbn.tiny, line 2")
    assert out[start + 3] == "// ~~~~~ end include rbn.tiny ~~~~~"
    assert bundling.resolve_line("\n".join(out), start + 3) == ("tiny", 2)
    assert bundling.resolve_line("\n".join(out), 5) is None


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


def test_check_reports_stale_then_fresh(tree: Path) -> None:
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
