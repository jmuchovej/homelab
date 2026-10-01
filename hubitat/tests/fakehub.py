"""Just enough of the hub's Drivers Code endpoints, behind ``httpx.MockTransport``, to
drive the create/update/skip/delete decisions without a hub."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from urllib.parse import parse_qs

import httpx

BASE = "http://hub.test"
ALERT = (
    '<div class="alert alert-danger"><div class="alert-close close" data-dismiss="alert" '
    'aria-label="Close"><span aria-hidden="true">&times;</span></div>{message}</div>'
)


@dataclass
class FakeHub:
    drivers: list[dict] = field(default_factory=list)
    codes: dict[int, dict] = field(default_factory=dict)
    requests: list[httpx.Request] = field(default_factory=list)
    secured: bool = False
    save_error: str | None = None
    update_error: str | None = None
    next_id: int = 100

    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self.handle)

    def handle(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        path = request.url.path
        form = parse_qs(request.content.decode()) if request.method == "POST" else {}
        if path == "/hub/edit":
            body = "<title>Login</title>" if self.secured else "<title>Hub</title>"
            return httpx.Response(200, text=body)
        if path == "/login":
            self.secured = form["password"] != ["right"]
            text = (
                "The login information you supplied was incorrect."
                if self.secured
                else ""
            )
            return httpx.Response(200, text=text)
        if path == "/hub2/userDeviceTypes":
            return httpx.Response(200, json=self.drivers)
        if path == "/driver/ajax/code":
            return httpx.Response(200, json=self.codes[int(request.url.params["id"])])
        if path == "/driver/save":
            if self.save_error:
                return httpx.Response(200, text=ALERT.format(message=self.save_error))
            source = form["source"][0]
            # The real hub names the driver from its definition(); do the same.
            name = re.search(r"\bname: '([^']+)'", source).group(1)
            namespace = re.search(r"\bnamespace: '([^']+)'", source).group(1)
            new_id = self.seed(name, namespace, source, version=1)
            return httpx.Response(
                302, headers={"Location": f"{BASE}/driver/editor/{new_id}"}
            )
        if path == "/driver/ajax/update":
            if self.update_error:
                return httpx.Response(
                    200, json={"status": "error", "errorMessage": self.update_error}
                )
            code = self.codes[int(form["id"][0])]
            assert form["version"] == [str(code["version"])]
            code["source"] = form["source"][0]
            code["version"] += 1
            return httpx.Response(200, json={"status": "success"})
        if path.startswith("/driver/editor/deleteJson/"):
            id = int(path.rsplit("/", 1)[-1])
            self.drivers = [d for d in self.drivers if d["id"] != id]
            self.codes.pop(id, None)
            return httpx.Response(200, json={"status": True})
        return httpx.Response(404, text=f"no route for {path}")

    def seed(self, name: str, namespace: str, source: str, version: int = 7) -> int:
        new_id, self.next_id = self.next_id, self.next_id + 1
        self.drivers.append({"id": new_id, "name": name, "namespace": namespace})
        self.codes[new_id] = {"source": source, "version": version}
        return new_id

    def paths(self, method: str | None = None) -> list[str]:
        return [
            r.url.path for r in self.requests if method is None or r.method == method
        ]

    def posts(self) -> list[str]:
        return self.paths("POST")
