# Custom Library Functions

Reusable Nix functions extending `nixpkgs.lib` for `rebellion`-specific
patterns.

## Library Structure

```shell
$ tree src/lib
  src/lib
├──   default.nix           # Bootstrap: two-phase lib assembly
├──   ai-tools.nix          # AI tool definition parser
├──   hcl.nix               # HCL (HashiCorp Config Language) generator
├──   modules.nix           # Module creation utilities (mk-module, mk-desktop-module)
├──   network.nix            # Traefik/Consul/Authentik service routing
├──   nomad.nix              # Nomad job spec generation
├──   options.nix            # NixOS option creation shortcuts (mk, mk-bool, mk-enable, etc.)
├──   vscode.nix             # VSCode extension/settings option builder
├──   zed.nix                # Zed editor settings builder
└──   lib/                   # Internal builders
    ├──   attrs.nix          # Attribute set manipulation (mk-default, mk-force, merge-attrs, etc.)
    ├──   deploy.nix         # deploy-rs node generation
    ├──   flake.nix          # Top-level mk-flake builder
    ├──   flake-options.part.nix  # Option schema for mk-flake
    ├──   fp.nix             # Functional programming combinators
    ├──   fs.nix             # Filesystem operations (walk-files, get-file, import-dir, etc.)
    ├──   home.nix           # Home-manager configuration discovery/building
    ├──   module.nix         # Internal module discovery and wrapping
    ├──   overlay.nix        # Overlay discovery and composition
    ├──   package.nix        # Package discovery with platform filtering
    ├──   path.nix           # Path/filename manipulation
    └──   system.nix         # System (NixOS/Darwin) discovery and building
```

## Naming Convention

All hand-crafted functions use **kebab-case** (e.g., `mk-module`, `get-file`,
`mk-traefik-service`).

## Core Principles

### 1. Pure Functions

All lib functions must be pure — no side effects, deterministic output.

### 2. Two-Phase Bootstrap (`default.nix`)

- **Phase 1**: Build `rebellion-lib` via `fix` (fixpoint recursion). Each file
  in `src/lib/` and `src/lib/lib/` is auto-discovered, imported, and merged.
- **Phase 2**: Construct `lib.rebellion.*` namespace with re-exports and curried
  `mk-flake`.

### 3. Namespaced Exports

Functions are available as `lib.rebellion.{category}.{function}`. Commonly used
functions are also re-exported to `lib.{function}` for convenience:

- `lib.mk-module`, `lib.mk-desktop-module`
- `lib.mk`, `lib.mk'`, `lib.mk-bool`, `lib.mk-enable`, `lib.enabled`,
  `lib.disabled`
- `lib.get-file`, `lib.import-dir`, `lib.scan-dir`, `lib.walk-files`, etc.

## Library Categories

- **attrs**: Attribute set manipulation (`mk-default`, `mk-force`,
  `merge-attrs`, `merge-deep`, `merge-shallow`)
- **fs**: File operations (`get-file`, `import-dir`, `scan-dir`, `walk-files`,
  `get-secret`, etc.)
- **fp**: Functional programming (`compose`, `compose-all`, `call`, `apply`)
- **path**: Path manipulation (`split-file-extension`, `has-file-extension`,
  `get-parent-directory`)
- **options**: NixOS option helpers (`mk`, `mk'`, `mk-bool`, `mk-enable`,
  `enabled`, `disabled`)
- **modules**: Module builders (`mk-module`, `mk-desktop-module`,
  `eval-if-func`, `get-shared`)
- **network**: Traefik/Consul integration (`mk-traefik-service`, `with-consul`,
  `mk-healthcheck`, `mk-authentik`)
- **nomad**: Nomad job generation (`mk-nomad-job`, `mk-docker-nomad-job`,
  `mk-gpu-nomad-job`)
- **hcl**: HCL generation (`to-hcl`, `labeled`, `raw`, `write-hcl`)
- **system**: System builders (`create-system`, `create-systems`, `is-linux`,
  `is-macos`)
- **home**: Home-manager builders (`create-home`, `create-homes`,
  `create-system-homes`)
- **deploy**: deploy-rs integration (`mk-deploy-nodes`)
- **overlay**: Overlay discovery (`discover-overlays`, `mk-packages-overlay`,
  `mk-overlays`)
- **package**: Package discovery (`mk-packages`)
- **flake**: Flake builder (`mk-flake`, `without-self`, `without-src`)

## Common Patterns

### Module Creation

```nix
{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "services.myservice";
  config = { cfg, lib, config, ... }: {
    # ...
  };
}
```

### Option Creation

```nix
inherit (lib.rebellion) mk mk-bool mk-enable enabled disabled;

options = {
  port = mk lib.types.int 8080 "Port to listen on";
  debug = mk-bool false "Enable debug mode";
};
```

### Service Registration (Traefik + Consul)

```nix
inherit (lib.rebellion.network) mk-traefik-service with-consul mk-healthcheck mk-authentik;

service = mk-traefik-service { name = "myapp"; port = 8080; hostname = "da-vcx-1"; datacenter = "da"; };
```

## Testing

```bash
# Test in nix repl
nix repl
> :lf .
> lib.rebellion.fs.get-file "modules"
/nix/store/.../modules

> lib.rebellion.fs.scan-dir ./src/lib
[ "ai-tools.nix" "default.nix" ... ]
```
