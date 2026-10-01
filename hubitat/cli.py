"""Command-line surface. Thin by rule: every command delegates to a module."""

from __future__ import annotations

from pathlib import Path
from typing import Annotated

import typer

import hubitat

from . import bump as bumping
from . import bundle as bundling
from . import manifest as manifests
from . import push as pushing
from .hub import Hub, HubConfig, HubConfigError, HubError

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


def _named_sources(names: list[str] | None) -> list[Path]:
    """``hubitat/drivers/<name>/<name>.groovy`` for each name; all drivers when none."""
    if not names:
        return _sources(None)
    sources = []
    for name in names:
        source = hubitat.DRIVERS / name / f"{name}.groovy"
        if not source.is_file():
            typer.echo(f"error: unknown driver {name!r} (no {source})", err=True)
            raise typer.Exit(2)
        sources.append(source)
    return sources


def _connect() -> Hub:
    try:
        config = HubConfig.from_env()
        return Hub.connect(config)
    except HubConfigError as error:
        typer.echo(f"error: {error}", err=True)
        raise typer.Exit(2) from None
    except HubError as error:
        typer.echo(f"error: {error}", err=True)
        raise typer.Exit(1) from None


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


Drivers = Annotated[
    list[str] | None,
    typer.Argument(help="Driver directory names under hubitat/drivers/; default: all."),
]
DryRun = Annotated[
    bool, typer.Option("--dry-run", help="Read from the hub, write nothing.")
]


@app.command()
def push(drivers: Drivers = None, dry_run: DryRun = False) -> None:
    """Create or update rbn drivers on the hub from their bundles; unchanged ones are skipped."""
    sources = _named_sources(drivers)
    with _connect() as hub:
        try:
            actions = pushing.plan(hub, sources)
            for action in actions:
                typer.echo(action.describe(dry_run=dry_run))
            if not dry_run:
                pushing.apply(hub, actions)
        except (pushing.PushError, manifests.IdentityError, HubError) as error:
            typer.echo(f"error: {error}", err=True)
            raise typer.Exit(1) from None


@app.command()
def probe() -> None:
    """Compile every library on the hub through a throwaway include-all driver, then delete it."""
    with _connect() as hub:
        try:
            names = pushing.probe(hub)
        except (pushing.ProbeError, pushing.PushError, HubError) as error:
            typer.echo(f"error: {error}", err=True)
            raise typer.Exit(1) from None
    typer.echo(f"compiled {len(names)} libraries: {', '.join(names)}")


@app.command()
def bump(
    driver: Annotated[
        str, typer.Argument(help="Driver directory name under hubitat/drivers/.")
    ],
    version: Annotated[str, typer.Argument(help="New version string, e.g. 3.3.1.")],
) -> None:
    """Set a driver's version(), timeStamp(), and manifest version/dateReleased; re-bundle."""
    source = _named_sources([driver])[0]
    try:
        written = bumping.bump(source, version)
    except bumping.BumpError as error:
        typer.echo(f"error: {error}", err=True)
        raise typer.Exit(1) from None
    for path in written:
        typer.echo(f"wrote {path}")
