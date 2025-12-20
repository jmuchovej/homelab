from pathlib import Path
from homelab.tools import discover_datacenters_systems
import itertools
from datetime import datetime, timezone, timedelta
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import (
    NoEncryption, PrivateFormat, Encoding
)
from cryptography.x509 import Certificate, Name, NameAttribute, CertificateBuilder, DNSName, ExtensionType
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey, RSAPublicKey

def gen_key(key_size: int = 2048) -> RSAPrivateKey:
    """
    Generate RSA private key for certificates.

    Parameters
    ----------
    key_size : int, optional
        RSA key size in bits (default: 2048).

    Returns
    -------
    RSAPrivateKey
        Generated RSA private key.
    """
    return rsa.generate_private_key(
        public_exponent=65537,
        key_size=key_size,
    )

def _attrs(name: str) -> list[NameAttribute]:
    """
    Create standard X.509 name attributes for certificates.

    Helper function that ensures consistent `x509.Name` attributes across
    CA and child certificates.

    Parameters
    ----------
    name : str
        Common Name (CN) for the certificate.

    Returns
    -------
    list of NameAttribute
        List of X.509 name attributes including country, state, locality,
        organization, and common name.
    """
    return [
        NameAttribute(NameOID.COUNTRY_NAME, "US"),
        NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "Homelab"),
        NameAttribute(NameOID.LOCALITY_NAME, "Homelab"),
        NameAttribute(NameOID.ORGANIZATION_NAME, "Rebellion Homelab"),
        NameAttribute(NameOID.COMMON_NAME, name),
    ]

def _builder(
    subject: Name,
    issuer: Name,
    priv_key: RSAPrivateKey,
    t1: datetime,
    dt: int,
    extensions: list[tuple[ExtensionType, bool]]
) -> Certificate:
    """
    Build and sign an X.509 certificate.

    Helper function that ensures consistent certificate building process
    across CA and child certificates.

    Parameters
    ----------
    subject : Name
        X.509 subject name for the certificate.
    issuer : Name
        X.509 issuer name (same as subject for self-signed CA).
    priv_key : RSAPrivateKey
        Private key used to sign the certificate.
    t1 : datetime
        Certificate validity start date.
    dt : int
        Certificate validity duration in days.
    extensions : list of tuple of (ExtensionType, bool)
        List of X.509 extensions and their critical flags.

    Returns
    -------
    Certificate
        Signed X.509 certificate.
    """
    builder = (
        CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(priv_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(t1)
        .not_valid_after(t1 + timedelta(days=dt))
    )

    for (extension, critical) in extensions:
        builder.add_extension(extension, critical=critical)

    return builder.sign(priv_key, hashes.SHA256())

def gen_cert_auth(
    priv_key: RSAPrivateKey,
    datacenter: str,
    t1: datetime = datetime.now(timezone.utc),
    duration: int = 365 * 10
) -> Certificate:
    """
    Generate self-signed CA certificate.

    Parameters
    ----------
    priv_key : RSAPrivateKey
        RSA private key for the CA.
    datacenter : str
        Datacenter identifier (e.g., "da", "en").
    t1 : datetime, optional
        Certificate validity start date (default: current UTC time).
    duration : int, optional
        Certificate validity duration in days (default: 3650, ~10 years).

    Returns
    -------
    Certificate
        Self-signed CA certificate.
    """

    attrs = _attrs(f"Rebellion {datacenter.upper()} CA")
    subject = issuer = x509.Name(attrs)

    ext1 = x509.BasicConstraints(ca=True, path_length=0)
    ext2 = x509.KeyUsage(
        digital_signature=True,
        key_cert_sign=True,
        crl_sign=True,
        key_encipherment=False,
        content_commitment=False,
        data_encipherment=False,
        key_agreement=False,
        encipher_only=False,
        decipher_only=False,
    )
    ext3 = x509.SubjectKeyIdentifier.from_public_key(priv_key.public_key())
    return _builder(subject, issuer, priv_key, t1, duration, [
        (ext1, True),
        (ext2, True),
        (ext3, False)
    ])

def gen_cert_child(
    priv_key: RSAPrivateKey,
    ca_cert: Certificate,
    ca_key: RSAPrivateKey,
    datacenter: str,
    name: str,
    suffix: str = "lab",
    t1: datetime = datetime.now(timezone.utc),
    duration: int = round(365 * 2.25),
) -> Certificate:
    """
    Generate wildcard certificate signed by the CA.

    Parameters
    ----------
    priv_key : RSAPrivateKey
        RSA private key for the wildcard certificate.
    ca_cert : Certificate
        CA certificate (issuer).
    ca_key : RSAPrivateKey
        CA private key (for signing).
    datacenter : str
        Datacenter identifier (e.g., "da", "en").
    name : str
        The common name for this certificate.
    suffix : str, optional
        Domain suffix (default: "lab").
    t1 : datetime, optional
        Certificate validity start date (default: current UTC time).
    duration : int, optional
        Certificate validity duration in days (default: 825, ~2.25 years).

    Returns
    -------
    Certificate
        Wildcard certificate signed by CA.
    """

    attrs = _attrs(name)
    subject = x509.Name(attrs)

    # Build Subject Alternative Names (SAN)
    # Only include datacenter-specific hosts to avoid conflicts between datacenters
    san_list: list[DNSName] = list(itertools.chain(*[[
            # Wildcard for services: *.da-vcx-1.lab, *.en-t65-1.lab
            x509.DNSName(f"*.{host}.{suffix}"),
            # Bare hostname: da-vcx-1.lab, en-t65-1.lab
            x509.DNSName(f"{host}.{suffix}"),
        ] for host in discover_datacenters_systems().get(datacenter, [])
    ]))


    ext1 = x509.SubjectAlternativeName(san_list)
    ext2 = x509.BasicConstraints(ca=False, path_length=None)
    ext3 = x509.KeyUsage(
        digital_signature=True,
        key_cert_sign=False,
        crl_sign=False,
        key_encipherment=True,
        content_commitment=True,
        data_encipherment=True,
        key_agreement=False,
        encipher_only=False,
        decipher_only=False,
    )
    ext4 = x509.SubjectKeyIdentifier.from_public_key(priv_key.public_key())
    ext5 = x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key())
    return _builder(subject, ca_cert.subject, priv_key, t1, duration, [
        (ext1, False),
        (ext2, True),
        (ext3, True),
        (ext4, False),
        (ext5, False),
    ])

def save_priv_key(key: RSAPrivateKey, path: Path) -> None:
    """
    Write the private key to a PEM file.

    Parameters
    ----------
    key : RSAPrivateKey
        RSA private key to save.
    path : Path
        Output file path.

    Notes
    -----
    File permissions are set to 0o600 (read/write for owner only).
    """
    with path.open("wb") as f:
        f.write(key.private_bytes(
            encoding=Encoding.PEM,
            format=PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=NoEncryption()
        ))
    path.chmod(0o600)  # Read/write for owner only

def save_cert(cert: Certificate, path: Path) -> None:
    """
    Write the certificate to a PEM file.

    Parameters
    ----------
    cert : Certificate
        X.509 certificate to save.
    path : Path
        Output file path.

    Notes
    -----
    File permissions are set to 0o644 (read for all, write for owner).
    """
    with path.open("wb") as f:
        f.write(cert.public_bytes(encoding=Encoding.PEM))
    path.chmod(0o644)  # Read for all, write for owner
