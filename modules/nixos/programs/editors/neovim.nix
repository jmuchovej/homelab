{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.editors.neovim";
  description = "neovim";
  options =
    { lib, ... }:
    let
      inherit (lib.rebellion) mkopt-enable;
    in
    {
      default = mkopt-enable "Neovim as the default $EDITOR";
    };
  config =
    { cfg, lib, ... }:
    let
      inherit (lib.rebellion) enabled;
    in
    {
      environment.sessionVariables = {
        EDITOR = lib.mkIf cfg.default "nvim";
      };

      programs.neovim = enabled;
    };
}
