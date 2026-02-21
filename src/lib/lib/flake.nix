## Top-level flake builder.
##
## Provides `rebellion.mk-flake` — a single entry point that orchestrates
## overlay discovery, system/home building, deploy nodes, packages, and
## dev tooling into a complete flake-parts-based flake output.
{
  lib,
  rebellion-lib,
  ...
}:
{
  flake = {
    ## Remove the `self` attribute from an attribute set.
    ## Example Usage:
    ## ```nix
    ## without-self { self = {}; x = true; }
    ## ```
    ## Result:
    ## ```nix
    ## { x = true; }
    ## ```
    #@ Attrs -> Attrs
    without-self = flake-inputs: removeAttrs flake-inputs [ "self" ];

    ## Remove the `src` attribute from an attribute set.
    ## Example Usage:
    ## ```nix
    ## without-src { src = ./.; x = true; }
    ## ```
    ## Result:
    ## ```nix
    ## { x = true; }
    ## ```
    #@ Attrs -> Attrs
    without-src = flake-inputs: removeAttrs flake-inputs [ "src" ];
  };

  mk-flake =
    final-lib: user-args:
    let
      # Validate and apply defaults via evalModules
      evaluated = final-lib.evalModules {
        modules = [
          ./flake-options.part.nix
          { config = user-args; }
        ];
      };
      cfg = evaluated.config;

      inherit (cfg)
        inputs
        src
        overlays
        systems
        username
        partitions
        paths
        modules
        ;

      # Overlay building
      overlay-config = rebellion-lib.overlay.mk-overlays {
        inherit paths overlays;
      };

      # System building — create-systems returns config objects with builders
      raw-systems = rebellion-lib.system.create-systems {
        inherit
          final-lib
          paths
          modules
          username
          ;
        overlays = overlay-config.all-overlays;
      };

      get-builders = builders: lib.mapAttrs (_: cfg: cfg.builder cfg) builders;

      # Invoke builders and split into nixos/darwin outputs
      nixosConfigurations = get-builders (
        lib.filterAttrs (_: cfg: cfg.output == "nixosConfigurations") raw-systems
      );

      darwinConfigurations = get-builders (
        lib.filterAttrs (_: cfg: cfg.output == "darwinConfigurations") raw-systems
      );

      # Standalone home building — create-homes returns config objects with builders
      raw-homes = rebellion-lib.home.create-homes {
        inherit final-lib paths username;
        modules = modules.homes or [ ];
        overlays = overlay-config.all-overlays;
      };

      # Invoke builders to produce final homeConfigurations
      homeConfigurations = get-builders raw-homes;

      # Deploy nodes
      deploy-nodes = rebellion-lib.deploy.mk-deploy-nodes nixosConfigurations;

      # Partition discovery (use src directly to avoid store-path context issues)
      partitions-path = src + "/src/partitions";
      discovered-partitions = rebellion-lib.fs.discover-partitions partitions-path;
      has-partitions = discovered-partitions != [ ];

      partition-imports = lib.optionals has-partitions [
        inputs.flake-parts.flakeModules.partitions
      ];

      partition-config = lib.optionalAttrs has-partitions {
        partitions = lib.listToAttrs (
          map (p: {
            inherit (p) name;
            value = {
              inherit (p) module;
            }
            // lib.optionalAttrs (p.extraInputsFlake != null) {
              inherit (p) extraInputsFlake;
            };
          }) discovered-partitions
        );

        partitionedAttrs = lib.foldl' (
          acc: p:
          let
            attrs =
              partitions.${p.name}.partitionedAttrs or [
                "checks"
                "devShells"
                "formatter"
              ];
          in
          acc // lib.genAttrs attrs (_: p.name)
        ) { } discovered-partitions;
      };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      partition-config
      // {
        inherit systems;

        imports = [
          inputs.home-manager.flakeModules.home-manager
        ]
        ++ partition-imports;

        flake = {
          inherit nixosConfigurations darwinConfigurations homeConfigurations;
          inherit (overlay-config) overlays;

          homeModules.default = paths.modules.home;
          deploy.nodes = deploy-nodes;

          rebellion = {
            inherit (overlay-config) overlays;
            external-overlays = overlays;
            inherit modules;
          };
        };

        perSystem =
          { pkgs, ... }:
          {
            packages = rebellion-lib.package.mk-packages {
              inherit pkgs paths;
            };
          };
      }
    );
}
