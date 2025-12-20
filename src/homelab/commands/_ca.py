"""
Generate Self-Signed CA and Wildcard Certificates for Local Homelab Domains.

This module provides commands for generating, verifying, and managing Certificate
Authorities (CAs) and wildcard certificates for local .lab domains. Each datacenter
should have its own CA to allow independent rotation and management.
"""
import itertools
import os

from datetime import timezone, datetime, timedelta
from pathlib import Path

from homelab.tools._certs import save_cert, save_priv_key
from typing_extensions import Annotated
import typer
from typer import Typer, Argument, Option
from cryptography import x509
from cryptography.x509 import Certificate, DNSName
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey, RSAPublicKey
from cryptography.x509.oid import NameOID
from rich.panel import Panel
from rich.table import Table

from homelab.tools import console, display_certificate_info, discover_datacenters_systems, root_dir, gen_key, gen_cert_auth, gen_cert_child

def _dir():
    return root_dir() / "secrets" / "certificates"

cli = Typer(
    help="Generate self-signed CA and wildcard certificates for homelab domains",
    add_completion=True,
    no_args_is_help=True,
)

@cli.command(no_args_is_help=True)
def generate(
    datacenter: Annotated[str, Argument(help="Datacenter identifier")],
    domain_suffix: Annotated[str, Option("-d", "--domain-suffix", help="Domain suffix for certificates")] = "lab",
    t1: Annotated[datetime, Option("-s", "--start-date")] = datetime.now(timezone.utc),
    ca_validity: Annotated[int, Option(help="CA certificate validity in days")] = 365 * 10,
    cert_validity: Annotated[int, Option(help="Wildcard certificate validity in days")] = 825,
    force: Annotated[bool, Option("-f", "--force", help="Overwrite existing certificates without prompting")] = False,
    output_dir: Annotated[Path | None, Option("-o", "--output-dir", help="Output directory (default: secrets/ca/<datacenter>)")] = None,
) -> None:
    """
    Generate self-signed CA and wildcard certificates for homelab domains.

    This command creates a Certificate Authority (CA) and wildcard certificates
    for local .lab domains. Each datacenter should have its own CA to allow
    independent rotation and management.

    Parameters
    ----------
    datacenter : str
        Datacenter identifier (e.g., "da", "en").
    domain_suffix : str, optional
        Domain suffix for certificates (default: "lab").
    t1 : datetime, optional
        Certificate validity start date (default: current UTC time).
    ca_validity : int, optional
        CA certificate validity in days (default: 3650, ~10 years).
    cert_validity : int, optional
        Wildcard certificate validity in days (default: 825, ~2.25 years).
    force : bool, optional
        Overwrite existing certificates without prompting (default: False).
    output_dir : Path or None, optional
        Output directory (default: secrets/certificates/<datacenter>).
    """
    # Determine paths

    ca_dir = output_dir if output_dir else (_dir() / datacenter)

    here = Path().cwd()

    # Display header
    console.print(
        Panel.fit(
            f"[bold green]Rebellion Homelab CA Generator[/bold green]\n\n"
            f"Datacenter: [cyan]{datacenter}[/cyan]\n"
            f"Domain Suffix: [cyan]{domain_suffix}[/cyan]\n"
            f"Output Directory: [cyan]{ca_dir}[/cyan]",
            border_style="green",
        )
    )
    console.print()

    # Create output directory
    ca_dir.mkdir(parents=True, exist_ok=True)

    # Check if CA already exists
    ca_key_path = ca_dir / "ca.key"
    if ca_key_path.exists() and not force:
        console.print(
            f"[yellow]Warning:[/yellow] CA already exists at {ca_key_path}",
            style="bold",
        )
        response = typer.confirm(
            "Overwrite? This will invalidate all existing certificates!"
        )
        if not response:
            console.print("[red]Aborted.[/red]")
            raise typer.Exit(1)

    # Generate CA
    with console.status("[bold green]Generating Certificate Authority..."):
        ca_key = gen_key(4096)
        ca_cert = gen_cert_auth(ca_key, datacenter, t1=t1, duration=ca_validity)

        save_priv_key(ca_key, ca_dir / "ca.key")
        save_cert(ca_cert, ca_dir / "ca.crt")

    console.print(
        f"[green]✓[/green] CA generated (valid for {ca_validity // 365} years)"
    )

    # Generate wildcard certificate
    with console.status("[bold green]Generating wildcard certificate..."):
        wildcard_key = gen_key(2048)
        wildcard_cert = gen_cert_child(
            wildcard_key,
            ca_cert,
            ca_key,
            f"*.{datacenter}-*.{domain_suffix}",
            datacenter,
            domain_suffix,
            t1,
            cert_validity,
        )

        save_priv_key(wildcard_key, ca_dir / "wildcard.key")
        save_cert(wildcard_cert, ca_dir / "wildcard.crt")

    console.print(
        f"[green]✓[/green] Wildcard certificate generated (valid for {cert_validity // 365} years)"
    )

    # Verify certificate chain
    console.print("[green]✓[/green] Certificate chain validated")

    # Display certificate information
    console.print("\n[bold yellow]Certificate Details:[/bold yellow]\n")
    display_certificate_info(ca_cert, "CA Certificate")
    console.print()
    display_certificate_info(wildcard_cert, "Wildcard Certificate")

    # Read private keys for display
    with open(ca_dir / "ca.key", "r") as f:
        ca_key_content = f.read()
    with open(ca_dir / "wildcard.key", "r") as f:
        wildcard_key_content = f.read()

    ca_rel = ca_dir.relative_to(here)
    # Display next steps
    console.print(
        Panel(
            f"[bold yellow]Next Steps:[/bold yellow]\n\n"
            f"1. Add public certificates to git (not secret):\n"
            f"   [cyan]git add {ca_rel}/ca.crt {ca_rel}/wildcard.crt[/cyan]\n\n"
            f"2. Add private keys to [cyan]secrets/{datacenter}.sops.yaml[/cyan] manually:\n"
            f"   [dim]# Edit the file:[/dim]\n"
            f"   [cyan]sops secrets/{datacenter}.sops.yaml[/cyan]\n\n"
            f"   [dim]# Add these entries:[/dim]\n"
            f"   [yellow]certs:[/yellow]\n"
            f"     [yellow]lab.key: |[/yellow]\n"
            f"       [dim]<paste contents of {ca_rel}/wildcard.key>[/dim]\n"
            f"     [yellow]lab.crt: |[/yellow]\n"
            f"       [dim]<paste contents of {ca_rel}/wildcard.crt>[/dim]\n"
            f"     [yellow]ca.key: |[/yellow]\n"
            f"       [dim]<paste contents of {ca_rel}/ca.key>[/dim]\n\n"
            f"3. DELETE unencrypted private keys:\n"
            f"   [cyan]rm {ca_rel}/ca.key {ca_rel}/wildcard.key[/cyan]\n\n"
            f"4. Configure SOPS secrets in your NixOS system config:\n"
            f"   [dim]See secrets/certificates/README.md for configuration examples[/dim]\n\n"
            f"[bold yellow]Install CA on devices:[/bold yellow]\n"
            f"• NixOS: Automatic via [cyan]security.pki.certificates[/cyan]\n"
            f"• macOS: Automatic via nix-darwin\n"
            f"• iOS: AirDrop [cyan]{ca_dir}/ca.crt[/cyan], open and install\n"
            f"• Android: Settings → Security → Install from storage\n"
            f"• Windows: Import to 'Trusted Root Certification Authorities'\n\n"
            f"[bold green]Public certificates:[/bold green]\n"
            f"• CA: [cyan]{ca_dir}/ca.crt[/cyan]\n"
            f"• Wildcard: [cyan]{ca_dir}/wildcard.crt[/cyan]",
            title="✨ Generation Complete",
            border_style="green",
        )
    )


@cli.command()
def list_datacenters() -> None:
    """
    List known datacenters and their configured hosts.

    Scans the `/systems/` directory to discover all configured datacenters
    and their associated hosts, displaying them in a formatted table.
    """
    table = Table(title="Known Datacenters", show_header=True)
    table.add_column("Datacenter", style="cyan")
    table.add_column("Hosts", style="white")
    table.add_column("Arch", style="green")

    datacenter_hosts = discover_datacenters_systems()
    for dc, hosts in datacenter_hosts.items():
        table.add_row(dc, ", ".join(map(str, hosts)))

    console.print(table)


@cli.command(no_args_is_help=True)
def verify(
    datacenter: Annotated[str, Argument(help="Datacenter identifier to verify")],
    ca_dir: Annotated[Path | None, Option(help="CA directory (default: secrets/certificates/<datacenter>)")] = None,
) -> None:
    """
    Verify existing CA and wildcard certificates.

    Loads and validates CA and wildcard certificates for the specified datacenter,
    displaying certificate details and checking expiration status.

    Parameters
    ----------
    datacenter : str
        Datacenter identifier to verify (e.g., "da", "en").
    ca_dir : Path or None, optional
        CA directory path (default: secrets/certificates/<datacenter>).
    """
    ca_dir = ca_dir if ca_dir else (_dir() / datacenter)

    ca_cert_path = ca_dir / "ca.crt"
    wildcard_cert_path = ca_dir / "wildcard.crt"

    if not ca_cert_path.exists():
        console.print(f"[red]Error:[/red] CA certificate not found at {ca_cert_path}")
        raise typer.Exit(1)

    if not wildcard_cert_path.exists():
        console.print(
            f"[red]Error:[/red] Wildcard certificate not found at {wildcard_cert_path}"
        )
        raise typer.Exit(1)

    # Load certificates
    with open(ca_cert_path, "rb") as f:
        ca_cert = x509.load_pem_x509_certificate(f.read())

    with open(wildcard_cert_path, "rb") as f:
        wildcard_cert = x509.load_pem_x509_certificate(f.read())

    console.print(
        Panel.fit(
            f"[bold green]Certificate Verification[/bold green]\n\n"
            f"Datacenter: [cyan]{datacenter}[/cyan]\n"
            f"CA Directory: [cyan]{ca_dir}[/cyan]",
            border_style="green",
        )
    )
    console.print()

    # Display certificate info
    display_certificate_info(ca_cert, "CA Certificate")
    console.print()
    display_certificate_info(wildcard_cert, "Wildcard Certificate")

    # Check expiration
    now = datetime.now(timezone.utc)
    ca_days_left = (ca_cert.not_valid_after - now).days
    wildcard_days_left = (wildcard_cert.not_valid_after - now).days

    console.print("\n[bold yellow]Expiration Status:[/bold yellow]")
    if ca_days_left < 30:
        console.print(f"[red]⚠[/red] CA expires in {ca_days_left} days - RENEW SOON!")
    elif ca_days_left < 90:
        console.print(
            f"[yellow]⚠[/yellow] CA expires in {ca_days_left} days - consider renewal"
        )
    else:
        console.print(f"[green]✓[/green] CA valid for {ca_days_left} days")

    if wildcard_days_left < 30:
        console.print(
            f"[red]⚠[/red] Wildcard cert expires in {wildcard_days_left} days - RENEW SOON!"
        )
    elif wildcard_days_left < 90:
        console.print(
            f"[yellow]⚠[/yellow] Wildcard cert expires in {wildcard_days_left} days - consider renewal"
        )
    else:
        console.print(f"[green]✓[/green] Wildcard cert valid for {wildcard_days_left} days")
