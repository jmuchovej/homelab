from __future__ import annotations

from pathlib import Path

import pytest

import hubitat

TINY_LIBRARY = """\
library(name: 'tiny', namespace: 'rbn', author: 'test', description: 'tiny', version: '0.0.1')
def tinyHello() { return 'hi' }
"""

PROBE_DRIVER = """\
/* probe driver */
#include rbn.tiny
static String version() { "1.2.3" }
static String timeStamp() {"2026/10/01 12:00 PM"}
metadata {
    definition(name: 'Probe Driver', namespace: 'rbn', author: 'test') {
        capability 'Sensor'
    }
}
"""


@pytest.fixture
def tree(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """A miniature ``hubitat/`` tree that the package's path constants point at."""
    libraries = tmp_path / "libraries"
    drivers = tmp_path / "drivers"
    libraries.mkdir()
    (drivers / "probe").mkdir(parents=True)
    (libraries / "tiny.groovy").write_text(TINY_LIBRARY, encoding="utf-8")
    (drivers / "probe" / "probe.groovy").write_text(PROBE_DRIVER, encoding="utf-8")
    monkeypatch.setattr(hubitat, "ROOT", tmp_path)
    monkeypatch.setattr(hubitat, "LIBRARIES", libraries)
    monkeypatch.setattr(hubitat, "DRIVERS", drivers)
    return tmp_path
