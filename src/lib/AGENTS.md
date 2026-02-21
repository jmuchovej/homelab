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
├──   modules.nix           # Module creation utilities (mk_module, mk_desktop_module)
├──   module-options.part.nix  # Option schema for mk_module (excluded from auto-discovery)
├──   network.nix            # Traefik/Consul/Authentik service routing
├──   nomad.nix              # Nomad job spec generation
├──   options.nix            # NixOS option creation shortcuts (mk, mk_bool, mk_enable, etc.)
├──   vscode.nix             # VSCode extension/settings option builder
├──   zed.nix                # Zed editor settings builder
└──   lib/                   # Internal builders
    ├──   attrs.nix          # Attribute set manipulation (mk_default, mk_force, merge_attrs, etc.)
    ├──   deploy.nix         # deploy-rs node generation
    ├──   flake.nix          # Top-level mk_flake builder
    ├──   flake-options.part.nix  # Option schema for mk_flake
    ├──   fp.nix             # Functional programming combinators
    ├──   fs.nix             # Filesystem operations (walk_files, get_file, import_dir, etc.)
    ├──   home.nix           # Home-manager configuration discovery/building
    ├──   module.nix         # Internal module discovery and wrapping
    ├──   overlay.nix        # Overlay discovery and composition
    ├──   package.nix        # Package discovery with platform filtering
    ├──   path.nix           # Path/filename manipulation
    └──   system.nix         # System (NixOS/Darwin) discovery and building
```

## Naming Convention

All hand-crafted functions use **snake_case** (e.g., `mk_module`, `get_file`,
`mk_traefik_service`).

## Core Principles

### 1. Pure Functions

All lib functions must be pure — no side effects, deterministic output.

### 2. Two-Phase Bootstrap (`default.nix`)

- **Phase 1**: Build `rebellion-lib` via `fix` (fixpoint recursion). Each file
  in `src/lib/` and `src/lib/lib/` is auto-discovered, imported, and merged.
- **Phase 2**: Construct `lib.rebellion.*` namespace with re-exports and curried
  `mk_flake`.

### 3. Namespaced Exports

Functions are available as `lib.rebellion.{category}.{function}`. Commonly used
functions are also re-exported to `lib.{function}` for convenience:

- `lib.mk_module`, `lib.mk_desktop_module`
- `lib.mk`, `lib.mk'`, `lib.mk_bool`, `lib.mk_enable`, `lib.enabled`,
  `lib.disabled`
- `lib.get_file`, `lib.import_dir`, `lib.scan_dir`, `lib.walk_files`, etc.

## Library Categories

- **attrs**: Attribute set manipulation (`mk_default`, `mk_force`,
  `merge_attrs`, `merge_deep`, `merge_shallow`)
- **fs**: File operations (`get_file`, `import_dir`, `scan_dir`, `walk_files`,
  `get_secret`, etc.)
- **fp**: Functional programming (`compose`, `compose_all`, `call`, `apply`)
- **path**: Path manipulation (`split_file_extension`, `has_file_extension`,
  `get_parent_directory`)
- **options**: NixOS option helpers (`mk`, `mk'`, `mk_bool`, `mk_enable`,
  `enabled`, `disabled`)
- **modules**: Module builders (`mk_module`, `mk_desktop_module`,
  `eval_if_func`, `get_shared`)
- **network**: Traefik/Consul integration (`mk_traefik_service`, `with_consul`,
  `mk_healthcheck`, `mk_authentik`)
- **nomad**: Nomad job generation (`mk_nomad_job`, `mk_docker_nomad_job`,
  `mk_gpu_nomad_job`)
- **hcl**: HCL generation (`to_hcl`, `labeled`, `raw`, `write_hcl`)
- **system**: System builders (`create_system`, `create_systems`, `is_linux`,
  `is_macos`)
- **home**: Home-manager builders (`create_home`, `create_homes`,
  `create_system_homes`)
- **deploy**: deploy-rs integration (`mk_deploy_nodes`)
- **overlay**: Overlay discovery (`discover_overlays`, `mk_packages_overlay`,
  `mk_overlays`)
- **package**: Package discovery (`mk_packages`)
- **flake**: Flake builder (`mk_flake`, `without_self`, `without_src`)

## Common Patterns

### Module Creation

```nix
{ lib, ... }@args:
lib.rebellion.mk_module args {
  name = "services.myservice";
  config = { cfg, lib, config, ... }: {
    # ...
  };
}
```

### Option Creation

```nix
inherit (lib.rebellion) mk mk_bool mk_enable enabled disabled;

options = {
  port = mk lib.types.int 8080 "Port to listen on";
  debug = mk_bool false "Enable debug mode";
};
```

### Service Registration (Traefik + Consul)

```nix
inherit (lib.rebellion.network) mk_traefik_service with_consul mk_healthcheck mk_authentik;

service = mk_traefik_service { name = "myapp"; port = 8080; hostname = "da-vcx-1"; datacenter = "da"; };
```

## Testing

```bash
# Test in nix repl
nix repl
> :lf .
> lib.rebellion.fs.get_file "modules"
/nix/store/.../modules

> lib.rebellion.fs.scan_dir ./src/lib
[ "ai-tools.nix" "default.nix" ... ]
```
