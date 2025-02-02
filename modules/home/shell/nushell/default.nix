{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption filterAttrs;
  inherit (lib.strings) hasInfix;

  cfg = config.${namespace}.shell.nushell;
in {
  options.${namespace}.shell.nushell = {
    enable = mkEnableOption "`nushell`";
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;

      shellAliases = filterAttrs (_k: v: !hasInfix " && " v) config.home.shellAliases;
    };
  };
}
