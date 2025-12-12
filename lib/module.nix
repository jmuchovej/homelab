{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib)
    mapAttrs
    mkOption
    types
    mkDefault
    mkForce
    attrsOf
    submodule
    listOf
    package
    ;

  JSON = (inputs.nixpkgs.formats.json { }).type;
in
rec {
  ## Create a NixOS module option.
  ##
  ## ```nix
  ## lib.mkopt nixpkgs.lib.types.str "My default" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt =
    type: default: description:
    mkOption { inherit type default description; };

  ## Create a NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkopt' nixpkgs.lib.types.str "My default"
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt' = type: default: mkopt type default null;

  ## Create a boolean NixOS module option.
  ##
  ## ```nix
  ## lib.mkopt-bool true "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt-bool = mkopt types.bool;

  ## Create a boolean NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkopt-bool' true
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt-bool' = mkopt' types.bool;

  ## Create an enablement optionn. There's no need to provide "Enable ...", just the description. "Enable" is a fixed prefix.
  ##
  ## ```nix
  ## lib.mkopt-enable "Enable {description}"
  ## ```
  ##
  #@ String
  mkopt-enable = description: mkopt-bool false "Enable `${description}`.";

  ## Create a package NixOS module option.
  ##
  ## ```nix
  ## lib.mkopt-package pkgs.rofi-wayland "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt-package = mkopt types.package;

  ## Create a package NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkopt-package' pkgs.rofi-wayland
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt-package' = mkopt types.package;

  # Original flake-parts module utilities
  # Enable a module with optional configuration
  enable =
    module: config:
    {
      imports = [ module ];
    }
    // config;

  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = disabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  # Conditionally enable modules based on system
  enable-for-system =
    system: modules:
    builtins.filter (
      mod: mod.systems or [ ] == [ ] || builtins.elem system (mod.systems or [ ])
    ) modules;

  # Create a module with common options
  mk-module =
    {
      name,
      description ? "",
      options ? { },
      config ? { },
    }:
    { lib, ... }:
    {
      options.rebellion.${name} = mkopt' submodule {
        options = {
          enable = mkopt-enable description;
        }
        // options;
      } { };

      config = lib.mkIf config.rebellion.${name}.enable config;
    };

  ## Alias to make loading shared configurations terse.
  get-shared =
    partial:
    let
      inherit (lib.rebellion) get-file;
    in
    get-file "modules/shared/${partial}/default.nix";

  ## Sugar to make nesting options a smidge quicker.
  mkopt-nested =
    options:
    mkopt' types.submodule {
      inherit options;
    };

  ## Sugar to make nesting `{..}.enable` options quicker.
  mkopt-nested-enable =
    feature:
    mkopt-nested {
      enable = mkopt-enable feature;
    };

  mkopt-vscode =
    extension-list: user-settings:
    mkopt' (attrsOf (submodule {
      options = {
        extensions = mkOption {
          type = listOf package;
          default = extension-list;
          description = "Extensions to add to VSCode";
        };
        userSettings = mkOption {
          type = JSON;
          default = user-settings;
          description = "User Settings to add to VSCode";
        };
      };
    })) { };

  default-attrs = mapAttrs (_key: mkDefault);

  force-attrs = mapAttrs (_key: mkForce);

  nested-default-attrs = mapAttrs (_key: default-attrs);

  nested-force-attrs = mapAttrs (_key: force-attrs);
}
