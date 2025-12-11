{
  inputs,
  config,
  ...
}:
{
  options = {
    # Define options for external modules
    rebellion = {
      overlays = inputs.nixpkgs.lib.mkOption {
        type = inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.unspecified;
        # default = [ ];
        description = "List of overlays to apply to all systems";
      };

      modules = {
        homes = inputs.nixpkgs.lib.mkOption {
          type = inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.unspecified;
          # default = [ ];
          description = "List of home-manager modules to apply";
        };

        nixos = inputs.nixpkgs.lib.mkOption {
          type = inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.unspecified;
          # default = [ ];
          description = "List of NixOS modules to apply";
        };

        macos = inputs.nixpkgs.lib.mkOption {
          type = inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.unspecified;
          # default = [ ];
          description = "List of macOS modules to apply";
        };
      };
    };
  };

  config = {
    # Make these available in the flake output
    flake.rebellion = {
      inherit (config.rebellion) overlays modules;
    };
  };
}
