## Option schema for `rebellion.mk-flake`.
##
## Consumed by `flake.nix` via `lib.evalModules` to validate and default
## the arguments passed to `mk-flake`. Uses `.part.nix` suffix so the
## library bootstrap ignores it.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
in
{
  options = {
    inputs = mkOption {
      type = types.attrs;
      description = "Flake inputs";
    };

    src = mkOption {
      type = types.path;
      description = "Root path of the flake (usually ./.)";
    };

    overlays = mkOption {
      type = types.listOf types.unspecified;
      default = [ ];
      description = "External overlays from inputs to apply to all systems";
    };

    modules = {
      nixos = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
        description = "NixOS modules from inputs to apply to all NixOS systems";
      };
      macos = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
        description = "Darwin modules from inputs to apply to all macOS systems";
      };
      homes = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
        description = "Home-manager modules from inputs to apply to all home configs";
      };
    };

    systems = mkOption {
      type = types.listOf types.str;
      default = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      description = "Supported system architectures";
    };

    username = mkOption {
      type = types.str;
      description = "Default username for system and home configurations";
    };

    paths = {
      systems = mkOption {
        type = types.path;
        readOnly = true;
        description = "Path to system configurations";
      };
      overlays = mkOption {
        type = types.path;
        readOnly = true;
        description = "Path to overlay definitions";
      };
      packages = mkOption {
        type = types.path;
        readOnly = true;
        description = "Path to package definitions";
      };
      homes = mkOption {
        type = types.path;
        readOnly = true;
        description = "Path to home configurations";
      };
      partitions = mkOption {
        type = types.path;
        readOnly = true;
        description = "Path to partition definitions";
      };
      modules = {
        nixos = mkOption {
          type = types.path;
          readOnly = true;
          description = "Path to NixOS modules";
        };
        macos = mkOption {
          type = types.path;
          readOnly = true;
          description = "Path to macOS modules";
        };
        home = mkOption {
          type = types.path;
          readOnly = true;
          description = "Path to home-manager modules";
        };
      };
    };

    partitions = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            partitionedAttrs = mkOption {
              type = types.listOf types.str;
              default = [
                "checks"
                "devShells"
                "formatter"
              ];
              description = "Flake output attrs owned by this partition";
            };
          };
        }
      );
      default = { };
      description = "Per-partition overrides (e.g., partitionedAttrs). Partitions are auto-discovered from src/partitions/.";
    };
  };

  config = {
    paths = {
      systems = config.src + "/systems";
      overlays = config.src + "/overlays";
      packages = config.src + "/packages";
      homes = config.src + "/homes";
      partitions = config.src + "/src/partitions";
      modules = {
        nixos = config.src + "/modules/nixos";
        macos = config.src + "/modules/macos";
        home = config.src + "/modules/home";
      };
    };
  };
}
