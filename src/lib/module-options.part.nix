## Option schema for `rebellion.mk-module`.
##
## Defines the input options for module specs and computes derived values
## (namespace path, base optionset, description). Exposes a `build` function
## that takes NixOS module-args and produces the final { imports, options, config }.
##
## Uses `.part.nix` suffix so the library bootstrap ignores it.
{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    types
    splitString
    setAttrByPath
    getAttrFromPath
    isFunction
    rebellion
    ;

  cfg = config;

  eval-if-func = maybe-fn: args: if isFunction maybe-fn then (maybe-fn args) else maybe-fn;
in
{
  options = {
    # --- User-provided inputs ---

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Module name under the `rebellion` namespace. Creates an `enable` option when set.";
    };

    namespace = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Module namespace (dot-separated). Like `name` but does not gate on `enable`.";
    };

    imports = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "List of modules or functions to import.";
    };

    description = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Human-readable description. Defaults to `name` or `namespace`.";
    };

    options = mkOption {
      type = types.raw;
      default = { };
      description = "Module options attrset or function receiving evaluation-args.";
    };

    config = mkOption {
      type = types.raw;
      default = { };
      description = "Module config attrset or function receiving evaluation-args.";
    };

    conditions = mkOption {
      type = types.raw;
      default = _: true;
      description = "Predicate function or boolean controlling whether config is applied.";
    };

    always-active = mkOption {
      type = types.bool;
      default = false;
      description = "When true, the `enable` option defaults to true.";
    };

    # --- Computed values ---

    effective-name = mkOption {
      type = types.nullOr types.str;
      readOnly = true;
      description = "Resolved name: namespace takes precedence over name.";
    };

    effective-description = mkOption {
      type = types.nullOr types.str;
      readOnly = true;
      description = "Resolved description: falls back to effective-name.";
    };

    name-parts = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Dot-split path segments prefixed with 'rebellion'.";
    };

    base-optionset = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "Auto-generated enable option (empty when name is null).";
    };

    # --- Builder ---

    build = mkOption {
      type = types.raw;
      readOnly = true;
      description = "Function: module-args -> { imports, options, config }";
    };
  };

  config = {
    effective-name = if cfg.namespace != null then cfg.namespace else cfg.name;

    effective-description = if cfg.description != null then cfg.description else cfg.effective-name;

    name-parts = [
      "rebellion"
    ]
    ++ (if cfg.effective-name == null then [ ] else splitString "." cfg.effective-name);

    base-optionset =
      if cfg.name != null then
        {
          enable =
            if cfg.always-active then
              rebellion.mk-bool true "Enable `${cfg.effective-description}`."
            else
              rebellion.mk-bool false "Enable `${cfg.effective-description}`.";
        }
      else
        { };

    build =
      module-args:
      let
        module-cfg = getAttrFromPath cfg.name-parts module-args.config;

        evaluation-args = module-args // {
          cfg = module-cfg;
        };

        evald-imports = map (imp: eval-if-func imp evaluation-args) cfg.imports;
        evald-config = eval-if-func cfg.config evaluation-args;
        evald-conditions = eval-if-func cfg.conditions evaluation-args;
        evald-options = eval-if-func cfg.options evaluation-args;

        should-enable = (cfg.effective-name == null) || (cfg.namespace != null) || module-cfg.enable;
      in
      {
        imports = evald-imports;
        options = setAttrByPath cfg.name-parts (cfg.base-optionset // evald-options);
        config = mkIf (should-enable && evald-conditions) evald-config;
      };
  };
}
