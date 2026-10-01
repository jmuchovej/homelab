"""HTTP client for the hub's Drivers Code and Libraries Code endpoints, used the way the
Hubitat Package Manager uses the driver ones (its Groovy source is their only
documentation). The library endpoints were confirmed against hub firmware 2.4.3.177:
``/hub2/userLibraries``, ``/library/ajax/code``, ``/library/save``,
``/library/ajax/update``, and ``/library/edit/deleteJson/<id>`` (not ``editor/``).

Configuration comes from the environment only — ``HUBITAT_URL``, and
``HUBITAT_USERNAME``/``HUBITAT_PASSWORD`` when the hub has security enabled — which is
what ``secretspec run -- …`` provides. Credentials are sent in the login form body and
never appear in any message this module raises or prints.
"""

from __future__ import annotations

import json
import os
import re
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any, Self

import httpx

LOGIN_TITLE = "<title>Login</title>"
LOGIN_REJECTED = "The login information you supplied was incorrect."


class HubConfigError(Exception):
    """Missing or unusable hub configuration (nothing was sent to the hub)."""


class HubError(Exception):
    """The hub was unreachable or answered with an error."""


@dataclass(frozen=True)
class HubConfig:
    url: str
    username: str | None = None
    password: str | None = None

    @classmethod
    def from_env(cls, environ: Mapping[str, str] = os.environ) -> HubConfig:
        url = environ.get("HUBITAT_URL", "").strip()
        if not url:
            raise HubConfigError(
                "HUBITAT_URL is not set; hub commands run through "
                "`secretspec run --reason '<why>' -- …` (declared in secretspec.toml)"
            )
        return cls(
            url=url.rstrip("/"),
            username=environ.get("HUBITAT_USERNAME") or None,
            password=environ.get("HUBITAT_PASSWORD") or None,
        )


@dataclass(frozen=True)
class HubDriver:
    id: int
    name: str
    namespace: str


HubLibrary = HubDriver


@dataclass(frozen=True)
class DriverCode:
    source: str
    version: Any


class Hub:
    def __init__(self, config: HubConfig, transport: httpx.BaseTransport | None = None):
        self.config = config
        self._client = httpx.Client(
            base_url=config.url,
            timeout=30.0,
            verify=False,
            follow_redirects=False,
            transport=transport,
        )

    @classmethod
    def connect(
        cls, config: HubConfig, transport: httpx.BaseTransport | None = None
    ) -> Self:
        """Open a session, logging in only if the hub reports security enabled."""
        hub = cls(config, transport)
        if hub.security_enabled():
            hub.login()
        return hub

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    def _request(self, method: str, path: str, **kwargs: Any) -> httpx.Response:
        try:
            response = self._client.request(method, path, **kwargs)
        except httpx.HTTPError as error:
            raise HubError(f"{method} {path}: {error}") from error
        if response.status_code >= 400:
            raise HubError(
                f"{method} {path}: HTTP {response.status_code}: {response.text[:500]}"
            )
        return response

    def _json(self, method: str, path: str, **kwargs: Any) -> Any:
        response = self._request(method, path, **kwargs)
        try:
            return response.json()
        except json.JSONDecodeError as error:
            raise HubError(
                f"{method} {path}: hub did not answer with JSON (HTTP {response.status_code}); "
                "is security enabled without credentials?"
            ) from error

    def security_enabled(self) -> bool:
        return LOGIN_TITLE in self._request("GET", "/hub/edit").text

    def login(self) -> None:
        if not (self.config.username and self.config.password):
            raise HubConfigError(
                "the hub has security enabled; set HUBITAT_USERNAME and HUBITAT_PASSWORD "
                "in your secretspec provider"
            )
        response = self._request(
            "POST",
            "/login",
            params={"loginRedirect": "/"},
            data={
                "username": self.config.username,
                "password": self.config.password,
                "submit": "Login",
            },
        )
        if LOGIN_REJECTED in response.text:
            raise HubError("the hub rejected the login")

    # Drivers Code and Libraries Code share one request shape; only the paths differ.

    def _list(self, path: str) -> list[HubDriver]:
        return [
            HubDriver(
                id=int(item["id"]),
                name=item["name"],
                namespace=item.get("namespace") or "",
            )
            for item in self._json("GET", path)
        ]

    def _code(self, path: str, id: int) -> DriverCode:
        data = self._json("GET", path, params={"id": id})
        return DriverCode(source=data["source"], version=data["version"])

    def _create(self, path: str, what: str, source: str) -> int:
        response = self._request(
            "POST", path, data={"id": "", "version": "", "create": "", "source": source}
        )
        location = response.headers.get("location")
        if not location:
            raise HubError(
                f"POST {path}: the hub did not create the {what}: {_alert(response.text)}"
            )
        return int(location.rstrip("/").rsplit("/", 1)[-1])

    def _update(self, path: str, id: int, version: Any, source: str) -> None:
        data = self._json(
            "POST", path, data={"id": id, "version": version, "source": source}
        )
        if data.get("status") != "success":
            raise HubError(f"POST {path}: {data.get('errorMessage') or data}")

    def drivers(self) -> list[HubDriver]:
        return self._list("/hub2/userDeviceTypes")

    def driver_code(self, id: int) -> DriverCode:
        return self._code("/driver/ajax/code", id)

    def create_driver(self, source: str) -> int:
        return self._create("/driver/save", "driver", source)

    def update_driver(self, id: int, version: Any, source: str) -> None:
        self._update("/driver/ajax/update", id, version, source)

    def delete_driver(self, id: int) -> None:
        data = self._json("GET", f"/driver/editor/deleteJson/{id}")
        if data.get("status") is not True:
            raise HubError(f"GET /driver/editor/deleteJson/{id}: {data}")

    def libraries(self) -> list[HubLibrary]:
        return self._list("/hub2/userLibraries")

    def library_code(self, id: int) -> DriverCode:
        return self._code("/library/ajax/code", id)

    def create_library(self, source: str) -> int:
        return self._create("/library/save", "library", source)

    def update_library(self, id: int, version: Any, source: str) -> None:
        self._update("/library/ajax/update", id, version, source)

    def delete_library(self, id: int) -> None:
        data = self._json("GET", f"/library/edit/deleteJson/{id}")
        if data.get("success") is not True:
            raise HubError(f"GET /library/edit/deleteJson/{id}: {data}")


def _alert(html: str) -> str:
    """The editor page's alert text, which is where a save-time compile error lands."""
    flat = re.sub(r"\s+", " ", html)
    match = re.search(r'aria-label="Close">.*?</div>(.+?)</div>', flat)
    text = match.group(1) if match else flat
    return re.sub(r"<[^>]+>", "", text).strip()[:500]
