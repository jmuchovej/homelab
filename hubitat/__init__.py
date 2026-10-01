"""Tooling for the ``rbn`` Hubitat libraries and drivers kept in this directory.

The directory is both the data tree (``libraries/``, ``drivers/``, ``bundles/``,
``apps/``) and the Python package that bundles, checks, and pushes it. It is a uv
workspace member with no build system, so it is never installed: run it from the
repository root as ``uv run --package hubitat -m hubitat <command>``.

Modules locate the data tree through ``ROOT``/``LIBRARIES``/``DRIVERS`` at call time
so tests can point them at a miniature tree.
"""

from pathlib import Path

__version__ = "0.1.0"

ROOT = Path(__file__).resolve().parent
LIBRARIES = ROOT / "libraries"
DRIVERS = ROOT / "drivers"
