{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.programs.editors.neovim;
in {
  options.rebellion.programs.editors.neovim = {
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
