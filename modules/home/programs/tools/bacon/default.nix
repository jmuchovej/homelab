{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.bacon;
in {
  options.${namespace}.programs.tools.bacon = {
    enable = mkEnableOption "bacon";
  };

  config = mkIf cfg.enable {
    # https://github.com/Canop/bacon/issues/65
    # https://dystroy.org/blog/bacon-everything-roadmap/
    programs.bacon = {
      enable = true;
      # package = pkgs.bacon;
    };
  };
}
