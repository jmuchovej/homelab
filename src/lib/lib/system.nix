{
  lib,
  rebellion-lib,
  inputs,
}:
let
  inherit (lib)
    filter
    any
    hasInfix
    removeSuffix
    splitString
    fix
    foldl
    concatMap
    elemAt
    ;
  inherit (builtins)
    attrNames
    attrValues
    length
    isString
    unsafeDiscardStringContext
    ;

  inherit (rebellion-lib) fs;
in
{
  system = rec {
    # -------------------------------------------------------------------------
    # Predicates
    # -------------------------------------------------------------------------

    is-linux = target: hasInfix "linux" target;

    is-macos =
      target:
      any (s: hasInfix s target) [
        "darwin"
        "macos"
      ];

    # -------------------------------------------------------------------------
    # Discovery
    # -------------------------------------------------------------------------

    ## Discover all system .nix files and return parsed entries.
    ## Returns list of { system, hostname, path }.
    #@ Path -> [Attrs]
    discover =
      systems-path:
      let
        system-files = fs.walk-files {
          depth = 1;
          exclude = "(.*\\.part\\.nix|topology\\.nix)";
        } systems-path;

        parse = file: {
          hostname = removeSuffix ".nix" (baseNameOf file);
          system = baseNameOf (dirOf file);
          path = file;
        };
      in
      map parse system-files;

    # -------------------------------------------------------------------------
    # Hostname / Datacenter / Peers
    # -------------------------------------------------------------------------

    ## Parse a hostname into { hostname, datacenter, nodename }.
    ## Example: "da-vcx-1" -> { hostname = "da-vcx-1"; datacenter = "da"; nodename = "vcx-1"; }
    #@ String -> Attrs
    split-hostname-and-datacenter =
      target:
      let
        raw-parts = splitString "@" (removeSuffix ".nix" (baseNameOf target));
        name-parts = filter isString raw-parts;

        nodename = elemAt name-parts 0;
        datacenter = if length name-parts > 1 then elemAt name-parts 1 else null;
        hostname = if datacenter != null then "${toString datacenter}-${nodename}" else nodename;
      in
      {
        inherit hostname nodename datacenter;
      };

    ## Get all configured system hostnames from flake outputs.
    #@ Inputs -> [Attrs]
    get-systems =
      inputs':
      let
        flake = inputs'.self;
        nixos-sys = if flake ? nixosConfigurations then (attrNames flake.nixosConfigurations) else [ ];
        macos-sys = if flake ? darwinConfigurations then (attrNames flake.darwinConfigurations) else [ ];
      in
      map split-hostname-and-datacenter (nixos-sys ++ macos-sys);

    # -------------------------------------------------------------------------
    # Nixpkgs configuration
    # -------------------------------------------------------------------------

    ## Build the nixpkgs config (overlays + settings).
    #@ [Overlay] -> Attrs
    mk-nixpkgs-config = overlays: {
      inherit overlays;
      config = {
        allowAliases = false;
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
    };

    # -------------------------------------------------------------------------
    # Snowfall-inspired system creation
    # -------------------------------------------------------------------------

    ## Get structured metadata for all systems under a target architecture.
    ## Example: get-system-metadata "/systems/x86_64-linux"
    ## Returns list of { path, name, target, host }.
    #@ Path -> [Attrs]
    get-system-metadata =
      target:
      let
        existing-systems = rebellion-lib.fs.get-module-files target;

        create-metadata =
          path:
          let
            name = unsafeDiscardStringContext (baseNameOf path);
            host = removeSuffix ".nix" name;
          in
          {
            inherit path host name;
            target = unsafeDiscardStringContext (baseNameOf target);
          };
      in
      map create-metadata existing-systems;

    ## Get the appropriate system builder for a target architecture.
    ## Returns a function that takes a config object and produces a final system.
    #@ String -> (Attrs -> SystemConfiguration)
    get-builder =
      target:
      let
        macos-builder =
          args:
          inputs.nix-darwin.lib.darwinSystem {
            inherit (args) system modules;
            specialArgs = args.special-args // {
              format = "darwin";
            };
          };
        linux-builder =
          args:
          inputs.nixpkgs.lib.nixosSystem {
            inherit (args) system modules;
            specialArgs = args.special-args // {
              format = "linux";
            };
          };
      in
      if is-macos target then macos-builder else linux-builder;

    ## Infer system name from path.
    #@ Path -> String
    infer-name = path: removeSuffix ".nix" (baseNameOf path);

    ## Get the flake output attribute for a system target.
    #@ String -> String
    get-output = target: if is-macos target then "darwinConfigurations" else "nixosConfigurations";

    ## Resolve a target directory name to a real Nix system identifier.
    ## Handles special cases like `x86_64-install-iso` → `x86_64-linux`.
    #@ String -> String
    resolve-system-from =
      target:
      let
        parts = splitString "-" target;
        arch = elemAt parts 0;
      in
      if hasInfix "-install-iso" target then "${arch}-linux" else target;

    ## Create a single system configuration object.
    ## Returns an intermediate config with { system, builder, output, modules, special-args, hostname }.
    ## The builder must be invoked separately: `cfg.builder cfg`
    #@ Attrs -> Attrs
    create-system =
      {
        final-lib,
        target ? "x86_64-linux",
        system ? resolve-system-from target,
        path,
        name ? infer-name path,
        host ? unsafeDiscardStringContext name,
        modules ? [ ],
        special-args ? { },
        channel-name ? "nixpkgs",
        builder ? get-builder target,
        output ? get-output target,
        systems ? { },
        paths,
        overlays ? [ ],
        username ? "john",
        home-modules ? [ ],
      }:
      let
        # Parse datacenter/nodename and derive the real hostname (da@vcx-1 → da-vcx-1)
        parsed = split-hostname-and-datacenter host;
        inherit (parsed) datacenter nodename hostname;

        # Build home-manager system modules via create-system-homes
        hm-modules = rebellion-lib.home.create-system-homes {
          inherit
            final-lib
            paths
            system
            hostname
            overlays
            username
            ;
          modules = home-modules;
        };

        peers = filter (p: p.datacenter == datacenter) (attrValues systems);
      in
      {
        channelName = channel-name;
        inherit
          system
          builder
          output
          hostname
          datacenter
          ;
        modules = [
          { _module.args.lib = final-lib; }
          {
            nixpkgs = {
              inherit overlays;
              config = {
                allowAliases = false;
                allowUnfree = true;
                permittedInsecurePackages = [ ];
              };
            };
          }
        ]
        ++ modules
        ++ hm-modules
        ++ [ path ];
        special-args = special-args // {
          inherit
            target
            system
            systems
            nodename
            datacenter
            peers
            username
            hostname
            ;
          inherit (inputs) self;
          lib = final-lib;
          host = hostname;
          flake-parts-lib = inputs.flake-parts.lib;
          inputs = rebellion-lib.flake.without-src inputs;
        };
      };

    ## Create all available systems from directory discovery.
    ## Returns { hostname = <config-object>; ... } where each config has a `builder` to invoke.
    #@ Attrs -> Attrs
    create-systems =
      {
        final-lib,
        paths,
        modules,
        systems ? { },
        overlays ? [ ],
        username ? "john",
      }:
      let
        targets = rebellion-lib.fs.get-directories paths.systems;
        targets-metadata = concatMap get-system-metadata targets;
        user-nixos-modules = rebellion-lib.module.create-modules {
          src = paths.modules.nixos;
        };
        user-macos-modules = rebellion-lib.module.create-modules {
          src = paths.modules.macos;
        };

        create-system' =
          created-systems: metadata:
          let
            overrides = systems.hosts.${metadata.host} or { };
            user-modules = attrValues (
              if is-macos metadata.target then user-macos-modules else user-nixos-modules
            );
            sys-modules = if is-macos metadata.target then (modules.macos or [ ]) else (modules.nixos or [ ]);
          in
          {
            ${metadata.host} = create-system (
              overrides
              // metadata
              // {
                inherit final-lib;
                systems = created-systems;
                modules = user-modules ++ (overrides.modules or [ ]) ++ sys-modules;
                home-modules = modules.homes or [ ];
                inherit paths overlays username;
              }
            );
          };
        created-systems = fix (
          created:
          foldl (systems: metadata: systems // (create-system' created metadata)) { } targets-metadata
        );
      in
      created-systems;
  };
}
