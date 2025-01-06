{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.programs.editors.neovim;
in {
  options.${namespace}.programs.editors.neovim = {
    enable = mkEnableOption "neovim";
    default = mkEnableOption "Neovim as the default $EDITOR";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables = {
      EDITOR = mkIf cfg.default "nvim";
    };

    programs.neovim = enabled;
  };
}
