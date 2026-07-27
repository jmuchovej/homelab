# suites/ — aspect bundles

`rbn.suite._.<name>` — curated `includes` lists with minimal owned config.
Suites are the only place aspects get bundled; hosts and users include suites
plus à-la-carte extras.

Hierarchy: `common` (universal floor: system base + CLI tools + shells) ←
`server` (adds `common` + `development` + hardening + the `lab` user) and
`desktop` (adds `common` + GUI floor). `development` is Nix-tooling extras.

A suite may own small config directly (e.g. `server` defines the `lab` user
and documentation trimming) — but the moment owned config grows a "why", it
should become its own aspect and be included instead.
