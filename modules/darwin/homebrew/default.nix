{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) submodule str;
  inherit (lib.${namespace}) mkNestedEnableOption;

  cfg = config.${namespace}.homebrew;
in {
  options.${namespace}.homebrew = {
    enable = mkEnableOption "homebrew";
    mas = {enable = mkEnableOption "Mac App Store downloads";};
  };

  config = mkIf cfg.enable {
    homebrew = {
      enable = true;

      global = {
        brewfile = true;
        autoUpdate = true;
      };

      onActivation = {
        autoUpdate = true;
        cleanup = "uninstall";
        upgrade = true;
      };

      taps = [
        "homebrew/bundle"
        "homebrew/services"
      ];
    };
  };
}
