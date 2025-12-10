{ lib, inputs, ... }:
let
  inherit (inputs.nixpkgs.lib)
    mapAttrs
    mkOption
    types
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
  ## lib.mkPackageOpt' pkgs.rofi-wayland
  ## ```
  ##
  #@ Type -> Any -> String
  mkopt-package' = mkopt types.package;

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
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  ## Alias to make loading shared configurations terse.
  get-shared =
    partial:
    let
      inherit (lib.snowfall.fs) get-file;

      path = "modules/shared/${partial}/default.nix";
    in
    get-file "${path}";

  ## Sugar to make nesting options a smidge quicker.
  mk-nested-options =
    options:
    let
      inherit (lib) mkOption;
      inherit (lib.types) submodule;
    in
    mkOption {
      type = submodule {
        inherit options;
      };
      default = { };
    };

  ## Sugar to make nesting `{..}.enable` options quicker.
  mk-nested-enable-option =
    feature:
    let
      inherit (lib) mkEnableOption;
    in
    mk-nested-options {
      enable = mkEnableOption feature;
    };

  mkopt-vscode =
    extension-list: user-settings:
    let
      inherit (lib) mkOption;
      inherit (lib.types)
        attrsOf
        submodule
        listOf
        package
        ;
    in
    mkOption {
      type = attrsOf (submodule {
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
      });
    };

  default-attrs = mapAttrs (_key: lib.mkDefault);

  force-attrs = mapAttrs (_key: lib.mkForce);

  nested-default-attrs = mapAttrs (_key: default-attrs);

  nested-force-attrs = mapAttrs (_key: force-attrs);
}
