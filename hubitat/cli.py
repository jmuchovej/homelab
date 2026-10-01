"""Command-line surface. Thin by rule: every command delegates to a module."""

from __future__ import annotations

from pathlib import Path
from typing import Annotated

import typer

import hubitat

from . import bundle as bundling
from . import manifest as manifests

app = typer.Typer(
    no_args_is_help=True,
    add_completion=False,
    help="Bundle, check, and push the rbn Hubitat libraries and drivers.",
)

Sources = Annotated[
    list[Path] | None,
    typer.Argument(
        help="Driver source files; default: every hubitat/drivers/*/*.groovy."
    ),
]


def _sources(sources: list[Path] | None) -> list[Path]:
    resolved = [p.resolve() for p in sources] if sources else bundling.driver_sources()
    if not resolved:
        typer.echo(f"no driver sources under {hubitat.DRIVERS}", err=True)
        raise typer.Exit(1)
    return resolved


@app.command()
def bundle(sources: Sources = None) -> None:
    """Regenerate <driver>.bundled.groovy from each source and its rbn.* libraries."""
    failed = False
    for source in _sources(sources):
        try:
            target = bundling.write(source)
        except bundling.BundleError as error:
            typer.echo(f"error: {error}", err=True)
            failed = True
            continue
        typer.echo(f"wrote {target}")
    if failed:
        raise typer.Exit(1)


@app.command()
def check(sources: Sources = None) -> None:
    """Exit non-zero naming every stale bundle or disagreeing HPM manifest; write nothing."""
    failed = False
    for source in _sources(sources):
        try:
            stale = bundling.is_stale(source)
        except bundling.BundleError as error:
            typer.echo(f"error: {error}", err=True)
            failed = True
            continue
        if stale:
            typer.echo(f"stale: {bundling.bundle_path(source)}", err=True)
            failed = True
        for problem in manifests.check_manifest(source):
            typer.echo(f"error: {problem}", err=True)
            failed = True
    for problem in manifests.check_repository():
        typer.echo(f"error: {problem}", err=True)
        failed = True
    if failed:
        raise typer.Exit(1)
