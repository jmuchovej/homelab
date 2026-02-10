import os
from collections import defaultdict
from enum import Enum
from pathlib import Path

from cryptography.x509 import Certificate, ExtensionNotFound
from cryptography.x509.oid import ExtensionOID
from pydantic import BaseModel
from rich.table import Table

from homelab.tools import console


def root_dir() -> Path:
    """
    Get the project root directory.

    Returns the project root directory from the `${PROJECT_ROOT}` environment
    variable if set, otherwise returns the current working directory.

    Returns
    -------
    Path
        Absolute path to the project root directory.
    """
    root = os.getenv("PROJECT_ROOT")

    if root:
        return Path(root)

    return Path().cwd().resolve()


def display_certificate_info(cert: Certificate, title: str) -> None:
    """
    Display certificate details in a formatted table.

    Parameters
    ----------
    cert : Certificate
        X.509 certificate to display.
    title : str
        Title for the information table.
    """
    table = Table(title=title, show_header=False, box=None)
    table.add_column("Field", style="cyan")
    table.add_column("Value", style="white")

    table.add_row("Subject", cert.subject.rfc4514_string())
    table.add_row("Issuer", cert.issuer.rfc4514_string())
    table.add_row("Valid From", str(cert.not_valid_before_utc))
    table.add_row("Valid Until", str(cert.not_valid_after_utc))

    # Add SAN if present
    try:
        san_ext = cert.extensions.get_extension_for_oid(
            ExtensionOID.SUBJECT_ALTERNATIVE_NAME
        )
        table.add_row("SAN", repr(san_ext))
    except ExtensionNotFound:
        pass

    console.print(table)


class Architecture(Enum):
    arm64 = "aarch64"
    amd64 = "x86_64"


class Platform(Enum):
    macos = "darwin"
    nixos = "linux"


class System(BaseModel):
    name: str
    datacenter: str
    arch: Architecture
    os: Platform

    def __init__(self, details: str, name: str) -> None:
        (arch, os) = details.split("-", maxsplit=1)
        (datacenter, name) = name.split("-", maxsplit=1)
        super().__init__(
            name=name, datacenter=datacenter, arch=Architecture(arch), os=Platform(os)
        )

    def __hash__(self) -> int:
        return hash((self.name, self.datacenter, self.arch, self.os))

    def __repr__(self) -> str:
        return f"System({self}, {self.arch.name}, {self.os.name})"

    def __str__(self) -> str:
        return f"{self.datacenter}-{self.name}"


def discover_datacenters_systems() -> dict[str, set[System]]:
    """
    Discover all datacenters and their systems from the systems directory.

    Scans the `/systems` directory structure to identify all configured systems
    and groups them by datacenter.

    Returns
    -------
    dict of str to set of System
        Dictionary mapping datacenter identifiers to sets of System objects.
        Each System contains name, datacenter, architecture, and OS platform.

    Notes
    -----
    We assume a directory strcture that matches `{arch}-{os}/{datacenter}-{nodename}`. The only component permitted to have `-` is `nodename`, all others should match the `[^-]+` RegEx.
    """
    here = root_dir()
    systems = defaultdict(set)

    for path in (here / "systems").rglob("*.nix"):
        (details, name) = path.parent.parts[-2:]
        if name.count("-") < 2:
            continue
        system = System(details=details, name=name)
        systems[system.datacenter].add(system)

    return dict(systems.items())
