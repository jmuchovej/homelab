{
  lib,
  rebellion-lib,
  inputs,
}:
let
  inherit (lib)
    attrValues
    elemAt
    filter
    mapAttrsToList
    match
    mkDefault
    foldl'
    removeSuffix
    ;
  inherit (builtins)
    split
    isString
    length
    unsafeDiscardStringContext
    ;

  sys = rebellion-lib.system;
in
{
  home = rec {
    # -------------------------------------------------------------------------
    # Discovery
    # -------------------------------------------------------------------------

    ## Get the username and hostname from a combined string.
    ## Example Usage:
    ## ```nix
    ## split-user-and-host "myuser@myhost"
    ## ```
    ## Result:
    ## ```nix
    ## { username = "myuser"; hostname = "myhost"; }
    ## ```
    #@ String -> Attrs
    split-user-and-host =
      target:
      let
        raw-parts = split "@" (removeSuffix ".nix" (baseNameOf target));
        name-parts = filter isString raw-parts;

        username = elemAt name-parts 0;
        hostname = if length name-parts > 1 then elemAt name-parts 1 else null;
      in
      {
        inherit username hostname;
      };

    ## Discover all home .nix files and split into base/host configs.
    ## Returns { base-homes, host-homes } — lists of parsed home entries.
    #@ Path -> Attrs
    discover =
      homes-path:
      let
        home-files = rebellion-lib.fs.walk-files {
          depth = 1;
          exclude = ".*\\.part\\.nix";
        } homes-path;

        parse =
          file:
          let
            stem = removeSuffix ".nix" (baseNameOf file);
            file-system = baseNameOf (dirOf file);
            parts = match "([^@]+)@(.+)" stem;
            username = if parts != null then elemAt parts 0 else stem;
            file-hostname = if parts != null then elemAt parts 1 else null;
          in
          {
            inherit username;
            system = file-system;
            hostname = file-hostname;
            path = file;
            key = stem;
          };

        all-homes = map parse home-files;
      in
      {
        base-homes = filter (h: h.hostname == null) all-homes;
        host-homes = filter (h: h.hostname != null) all-homes;
      };

    # -------------------------------------------------------------------------
    # Standalone homeConfigurations builder
    # -------------------------------------------------------------------------

    ## Get structured metadata for all homes under a target architecture.
    ## Returns list of { path, name, system, username, hostname }.
    #@ Path -> [Attrs]
    get-home-metadata =
      target:
      let
        existing-homes = rebellion-lib.fs.get-module-files target;
        create-metadata =
          path:
          let
            name = builtins.unsafeDiscardStringContext (baseNameOf path);
            user-metadata = split-user-and-host name;
          in
          {
            inherit path name;
            system = infer-name target;
            inherit (user-metadata) username hostname;
          };
      in
      map create-metadata existing-homes;

    infer-name = name: unsafeDiscardStringContext (removeSuffix ".nix" (baseNameOf name));

    ## Create a single standalone home configuration object.
    ## Returns an intermediate config with { system, output, modules, special-args, builder }.
    ## The builder must be invoked separately: `cfg.builder cfg`
    #@ Attrs -> Attrs
    create-home =
      {
        final-lib,
        path,
        name ? infer-name path,
        modules ? [ ],
        special-args ? { },
        system ? "x86_64-linux",
        overlays ? [ ],
        username,
        hostname,
      }:
      let
        nixpkgs-config = sys.mk-nixpkgs-config overlays;
        pkgs = import inputs.nixpkgs-unstable {
          inherit system;
          inherit (nixpkgs-config) config overlays;
        };
      in
      {
        inherit system username hostname;
        output = "homeConfigurations";

        modules = [ path ] ++ modules;

        special-args = {
          # NOTE: home-manager has trouble with `pkgs` recursion if it
          # isn't passed from the top-level on downwards.
          lib = final-lib;
          inherit pkgs system;
          inherit username hostname;
          inherit (inputs) self;
          format = "home";
          inputs = rebellion-lib.flake.without-src inputs;
          flake-parts-lib = inputs.flake-parts.lib;
        }
        // special-args;

        builder =
          args:
          inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            extraSpecialArgs = args.special-args;

            modules = [
              { _module.args.lib = final-lib; }
              {
                home.username = mkDefault username;
                home.homeDirectory =
                  let
                    prefix = if rebellion-lib.system.is-macos system then "/Users" else "/home";
                    dir = "${prefix}/${username}";
                  in
                  mkDefault dir;
              }
            ]
            ++ args.modules;
          };
      };

    ## Create all available standalone home configurations from directory discovery.
    ## Returns { name = <config-object>; ... } where each config has a `builder` to invoke.
    #@ Attrs -> Attrs
    create-homes =
      {
        final-lib,
        paths,
        modules ? [ ],
        overlays ? [ ],
        username ? "john",
      }:
      let
        targets = rebellion-lib.fs.get-directories paths.homes;
        targets-metadata = lib.concatMap get-home-metadata targets;

        user-home-modules = attrValues (
          rebellion-lib.module.create-modules {
            src = paths.modules.home;
          }
        );

        create-home' =
          metadata:
          let
            stem = removeSuffix ".nix" metadata.name;
            # Use system-prefixed key when the same username exists in multiple architectures
            # to prevent collisions (e.g., aarch64-darwin/john.nix vs x86_64-linux/john.nix)
            key = "${metadata.system}/${stem}";
          in
          {
            "${key}" = create-home (
              metadata
              // {
                modules = user-home-modules ++ modules;
                inherit overlays final-lib;
              }
            );
          };

        created-homes = foldl' (homes: metadata: homes // (create-home' metadata)) { } targets-metadata;
      in
      created-homes;

    # -------------------------------------------------------------------------
    # System-embedded home-manager modules
    # -------------------------------------------------------------------------

    ## Create NixOS/Darwin modules that embed home-manager user configs.
    ##
    ## Discovers homes via `create-homes`, filters to those matching the
    ## target system/hostname, and produces a list of NixOS/Darwin modules that:
    ##   1. Set `home-manager.extraSpecialArgs` for all users
    ##   2. Add discovered `modules/home/*.nix` as shared HM modules
    ##   3. Add per-user `home-manager.users.<name>` with imports
    ##
    ## This mirrors snowfall-lib's `create-home-system-modules`.
    #@ Attrs -> [Module]
    create-system-homes =
      {
        final-lib,
        paths,
        system,
        hostname,
        modules ? [ ],
        overlays ? [ ],
        username ? "john",
      }:
      let
        # Build all home config objects, then filter to matching system/hostname
        all-homes = create-homes {
          inherit
            final-lib
            paths
            overlays
            username
            modules
            ;
        };

        matching-homes = lib.filterAttrs (
          _name: cfg: cfg.system == system && (cfg.hostname == null || cfg.hostname == hostname)
        ) all-homes;
      in
      if matching-homes == { } then
        [ ]
      else
        let
          # Module: inject extraSpecialArgs into home-manager context
          extra-special-args-module =
            {
              pkgs,
              system ? pkgs.stdenv.hostPlatform.system,
              target ? system,
              hostname ? "",
              systems ? { },
              ...
            }:
            {
              _file = "virtual:rebellion/home/extra-special-args";

              config.home-manager.extraSpecialArgs = {
                inherit
                  system
                  target
                  systems
                  hostname
                  ;
                inherit (inputs) self;
                lib = final-lib;
                inputs = rebellion-lib.flake.without-src inputs;
                flake-parts-lib = inputs.flake-parts.lib;
              };
            };

          # Modules: add user-provided modules as shared HM modules
          shared-modules = map (module: {
            _file = "virtual:rebellion/home/shared-module";
            config.home-manager.sharedModules = [ module ];
          }) modules;

          # Modules: add rebellion-extended lib to all HM modules
          lib-module = {
            _file = "virtual:rebellion/home/lib";
            config.home-manager.sharedModules = [
              { _module.args.lib = final-lib; }
            ];
          };

          # Modules: per-user home-manager configuration
          user-modules = mapAttrsToList (
            _name: home-config:
            let
              inherit (home-config) username;
              is-macos = rebellion-lib.system.is-macos system;
              prefix = if is-macos then "/Users" else "/home";
              dir = "${prefix}/${username}";
            in
            {
              _file = "virtual:rebellion/home/user/${username}";
              config = {
                # Ensure NixOS user account exists for this HM user
                users.users.${username} = lib.mkIf (!is-macos) {
                  isNormalUser = mkDefault true;
                  home = mkDefault dir;
                };

                home-manager = {
                  useGlobalPkgs = mkDefault true;
                  useUserPackages = mkDefault true;

                  users.${username} = {
                    imports = home-config.modules;
                    home = {
                      inherit username;
                      homeDirectory = mkDefault dir;
                    };
                  };
                };
              };
            }
          ) matching-homes;
        in
        [
          extra-special-args-module
          lib-module
        ]
        ++ shared-modules
        ++ user-modules;

  };
}
