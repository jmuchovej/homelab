"""
Install NixOS onto a target host via `nixos-anywhere`.

The target is reached by SSH at `root@<addr>` — either already booted from
the bootstrap ISO or any reachable Linux. `nixos-anywhere` handles kexec
into the noninteractive NixOS installer itself when needed.
"""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import time
import typing as t
from contextlib import contextmanager
from pathlib import Path
from tempfile import TemporaryDirectory

import typer
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
    PublicFormat,
    load_ssh_private_key,
)
from rich.panel import Panel
from sopsy import Sops, SopsyInOutType
from typer import Argument, Option, Typer
from typing_extensions import Annotated

from homelab.tools import console, root_dir

cli = Typer(
    help="Install NixOS onto a target host via nixos-anywhere.",
    add_completion=True,
    no_args_is_help=True,
)


def _wait_online(addr: str, *, timeout: int = 300) -> None:
    """Block until `addr` answers ICMP, then return. Aborts on timeout."""
    deadline = time.monotonic() + timeout
    with console.status(f"[bold green]Waiting for {addr}..."):
        while time.monotonic() < deadline:
            proc = subprocess.run(
                shlex.split(f"ping -c1 -W2 {addr}"), capture_output=True
            )
            if proc.returncode == 0:
                return
            time.sleep(2)

    console.print(f"[red]Error:[/red] {addr} did not respond within {timeout}s")
    raise typer.Exit(1)


@contextmanager
def _stage_extra_files(name: str, host_dir: Path, root: Path):
    """
    Yield a staging directory for `nixos-anywhere --extra-files`.

    Merges any pre-committed `<host_dir>/root/` tree with the host's ed25519
    SSH host privkey — decrypted from `secrets/hosts/<name>.sops.yaml` and
    converted from PKCS#8 to OpenSSH on the fly — placed at
    `/etc/ssh/ssh_host_ed25519_key` so sops-nix can derive the host's age
    identity on first boot.
    """
    with TemporaryDirectory(prefix=f"rbn-bootstrap-{name}-") as stage_str:
        stage = Path(stage_str)

        src = host_dir / "root"
        if src.exists():
            shutil.copytree(src, stage, dirs_exist_ok=True)

        sops_file = root / "secrets" / "hosts" / f"{name}.sops.yaml"
        data = Sops(sops_file, output_type=SopsyInOutType.YAML)
        data = t.cast(dict[str, str], data.decrypt(to_dict=True))
        key = load_ssh_private_key(data["host-key"].strip().encode(), password=None)

        ssh_dir = stage / "etc" / "ssh"
        ssh_dir.mkdir(parents=True, exist_ok=True)

        priv = key.private_bytes(
            encoding=Encoding.PEM,
            format=PrivateFormat.OpenSSH,
            encryption_algorithm=NoEncryption(),
        )
        priv_path = ssh_dir / "ssh_host_ed25519_key"
        priv_path.write_bytes(priv)
        priv_path.chmod(0o600)

        pub = key.public_key().public_bytes(
            encoding=Encoding.OpenSSH,
            format=PublicFormat.OpenSSH,
        )
        (ssh_dir / "ssh_host_ed25519_key.pub").write_bytes(pub + b"\n")

        yield stage


def _resolve_iso_key(ref: str | None) -> Path:
    """
    Resolve an iso-key reference to a filesystem path usable with `ssh -i`.

    Takes either an explicit path (with `~` expansion) or, if `None`,
    falls back to `$RBN_ISO_KEY`. The actual sourcing of the key bytes
    (1Password sync, manual placement, whatever) lives outside this CLI.
    """
    ref = ref or os.environ.get("RBN_ISO_KEY")
    if not ref:
        console.print(
            "[red]Error:[/red] No iso-key path. "
            "Pass --iso-key <path> or set RBN_ISO_KEY."
        )
        raise typer.Exit(1)

    path = Path(ref).expanduser()
    if not path.exists():
        console.print(f"[red]Error:[/red] iso-key path {path} not found.")
        raise typer.Exit(1)
    return path


@cli.command(no_args_is_help=True)
def bootstrap(
    name: Annotated[
        str,
        Argument(help="Target host (must match nixosConfigurations.<name>)"),
    ],
    addr: Annotated[str, Argument(help="Target IPv4 address")],
    iso_key: Annotated[
        t.Optional[str],
        Option(
            "--iso-key",
            help=(
                "Filesystem path to the iso-key private for SSH auth to the "
                "bootstrap ISO. Defaults to $RBN_ISO_KEY."
            ),
        ),
    ] = None,
    yes: Annotated[
        bool,
        Option("-y", "--yes", help="Skip the confirmation prompt"),
    ] = False,
) -> None:
    """Wipe `name` at `addr`, install NixOS, and print the host's age pubkey."""
    root = root_dir()
    host_dir = root / "src" / "modules" / "hosts" / f"{name}"
    facter_out = host_dir / "facter.json"

    console.print(
        Panel.fit(
            f"[bold green]✨ Joining the Rebellion ✨[/bold green]\n\n"
            f"Host:    [cyan]{name}[/cyan]\n"
            f"Target:  [cyan]root@{addr}[/cyan]\n"
            f"Facter:  [cyan]{facter_out.relative_to(root)}[/cyan]",
            border_style="green",
        )
    )
    console.print("[yellow]This will WIPE the target.[/yellow]")
    if not yes and not typer.confirm("Proceed?", default=False):
        console.print("[red]Aborted.[/red]")
        raise typer.Exit(1)

    identity = _resolve_iso_key(iso_key)

    console.print("\n✅ [bold]Running nixos-anywhere...[/bold]")
    host_dir.mkdir(parents=True, exist_ok=True)
    with _stage_extra_files(name, host_dir, root) as extra:
        cmd = (
            "nix run github:nix-community/nixos-anywhere --"
            f" --flake .#{name}"
            f" --generate-hardware-config nixos-facter {facter_out}"
            f" --target-host root@{addr}"
            f" --extra-files {extra}"
            f" -i {identity}"
            " --ssh-option IdentitiesOnly=yes"
        )
        subprocess.run(shlex.split(cmd), cwd=root, check=True)

    _wait_online(addr)
    console.print("\n[bold green]🚀 Done.[/bold green]")
