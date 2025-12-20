from typing_extensions import Annotated

import typer
from typer import Context, Option, Typer

from homelab.commands import _ca

cli = Typer(
    name="homelab",
    help="Rebellion Homelab management tools",
    add_completion=True,
    no_args_is_help=True,
    invoke_without_command=True,
)

def _version_callback(requested: bool) -> None:
    """
    Show version information.

    Parameters
    ----------
    requested : bool
        Whether version information was requested via --version flag.
    """
    if requested:
        from homelab._about import __version__
        typer.echo(f"v{__version__}")


@cli.callback()
def common(
    ctx: Context,
    version: Annotated[bool, Option("--version", callback=_version_callback)] = False,
):
    pass


cli.add_typer(_ca.cli)
