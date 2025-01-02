{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption filterAttrs strings;
  inherit (lib.strings) hasInfix;
  inherit (lib.${namespace});

  cfg = config.${namespace}.programs.shells.nushell;
in
{
  options.${namespace}.programs.shells.nushell = {
    enable = mkEnableOption "Enable `nushell`?";
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;

      shellAliases = filterAttrs (_k: v: !hasInfix " && " v) config.home.shellAliases;
    };
  };
}
