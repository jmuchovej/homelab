{
  lib,
  rebellion-lib,
  inputs,
}:
let
  inherit (lib)
    splitString
    setAttrByPath
    getAttrFromPath
    mkIf
    isFunction
    filter
    elem
    ;
in
{
  modules = rec {
    ## Conditionally enable modules based on system.
    #@ String -> [Module] -> [Module]
    enable-for-system =
      system: modules:
      filter (mod: mod.systems or [ ] == [ ] || elem system (mod.systems or [ ])) modules;

    ## Evaluate a value if it's a function, otherwise return as-is.
    #@ a -> Attrs -> a
    eval-if-func = maybe-fn: args: if isFunction maybe-fn then (maybe-fn args) else maybe-fn;

    ## Create a module with common options under the `rebellion` namespace.
    #@ ModuleArgs -> ModuleSpec -> Module
    mk-module =
      module-args:
      {
        name ? null,
        namespace ? null,
        imports ? [ ],
        description ? (if name != null then name else namespace),
        options ? { },
        config ? { },
        conditions ? _: true,
        always-active ? false,
      }:
      let
        eff-name = if namespace != null then namespace else name;
        eff-parts = if eff-name == null then [ ] else (splitString "." eff-name);
        name-parts = [ "rebellion" ] ++ eff-parts;
        cfg = getAttrFromPath name-parts module-args.config;

        eval-args = module-args // {
          inherit cfg;
        };

        evald-imports = map (imp: eval-if-func imp eval-args) imports;
        evald-config = eval-if-func config eval-args;
        evald-guards = eval-if-func conditions eval-args;
        evald-options = eval-if-func options eval-args;

        inherit (rebellion-lib.options) mk-enable;
        basic-options = if name != null then mk-enable description always-active else { };

        should-enable = (eff-name == null) || (namespace != null) || cfg.enable;
      in
      {
        imports = evald-imports;
        options = setAttrByPath name-parts (basic-options // evald-options);
        config = mkIf (should-enable && evald-guards) evald-config;
      };

    ## Create a desktop module (only active when rebellion.desktop.enable is true).
    #@ ModuleArgs -> ModuleSpec -> Module
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
        inherit (module-args.config.rebellion) desktop;
        evald-conditions =
          if builtins.isFunction conditions then
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

    ## Load a shared module by relative path.
    #@ String -> Path
    get-shared = partial: rebellion-lib.fs.get-file "modules/shared/${partial}/default.nix";
  };
}
