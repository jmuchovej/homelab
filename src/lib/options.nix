{
  lib,
  rebellion-lib ? { },
  inputs ? { },
}:
let
  inherit (lib.options) mkOption;
  inherit (lib) types;
in
{
  options = rec {
    ## Create a NixOS module option.
    #@ Type -> Any -> String -> Option
    mk =
      type: default: description:
      mkOption {
        inherit type default description;
      };

    ## Create a NixOS module option without a description.
    #@ Type -> Any -> Option
    mk' = type: default: mk type default null;

    ## Create a boolean NixOS module option.
    #@ Bool -> String -> Option
    mk-bool = mk types.bool;

    ## Create a boolean NixOS module option without a description.
    #@ Bool -> Option
    mk-bool' = mk' types.bool;

    ## Create a package option.
    #@ Package -> String -> Option
    mk-package = mk types.package;

    ## Create a package option without a description.
    #@ Package -> Option
    mk-package' = mk' types.package;

    ## Create an enable option. Provide the description name and it's default value.
    #@ String -> Bool -> Option
    mk-enable = name: default: {
      enable = mk-bool default "Where to enable ${name}.";
    };
    ## Create an enable option. Just provide the description noun. (With a `false` default.)
    #@ String -> Option
    mk-enable' = name: mk-enable name false;

    ## Shorthand for { enable = true; }
    enabled = {
      enable = true;
    };

    ## Shorthand for { enable = false; }
    disabled = {
      enable = false;
    };
  };
}
