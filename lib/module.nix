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
  ##@ Type -> Any -> String
  mkopt =
    type: default: description:
    mkOption { inherit type default description; };

  ## Create a NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkopt' nixpkgs.lib.types.str "My default"
  ## ```
  ##
  #@ Type -> Any
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

  eval-if-func =
    maybe-fn: args:
    let
      inherit (builtins) isFunction;
    in
    if isFunction maybe-fn then (maybe-fn args) else maybe-fn;

  # Create a module with common options
  # Usage: mk-module moduleArgs { name = "mymodule"; config = args: { ... }; }
  mk-module =
    module-args:
    {
      name,
      imports ? [ ],
      description ? name,
      options ? { },
      config ? { },
      conditions ? _: true,
    }:
    let
      inherit (module-args) lib;
      inherit (lib) setAttrByPath getAttrFromPath splitString;

      name-parts = [ "rebellion" ] ++ (if name == null then [ ] else (splitString "." name));
      cfg = getAttrFromPath name-parts module-args.config;

      evaluation-args = module-args // {
        inherit cfg;
      };
      # Always evaluate config as a function with full module args
      evald-config = eval-if-func config evaluation-args;
      evald-conditions = eval-if-func conditions evaluation-args;
      evald-options = eval-if-func options evaluation-args;

      base-optionset = if (name != null) then { enable = mkopt-enable description; } else { };
      should-enable = (name == null) || cfg.enable;
    in
    {
      inherit imports;
      options = setAttrByPath name-parts (base-optionset // evald-options);
      config = lib.mkIf (should-enable && evald-conditions) evald-config;
    };

  mk-desktop-module =
    module-args:
    {
      name,
      imports ? [ ],
      description ? name,
      options ? { },
      config ? { },
      conditions ? _: true,
    }:
    let
      inherit (builtins) isFunction;
      desktop = module-args.config.rebellion.desktop;

      evald-conditions =
        if isFunction conditions then
          (args: desktop.enable && conditions args)
        else
          desktop.enable && conditions;
    in
    mk-module module-args {
      inherit
        name
        imports
        description
        options
        config
        ;
      conditions = evald-conditions;
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
