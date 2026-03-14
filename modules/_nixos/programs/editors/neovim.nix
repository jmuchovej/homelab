{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.editors.neovim";
  description = "neovim";
  options =
    { lib, ... }:
    let
      inherit (lib.rebellion.options) mk-enable';
    in
    {
      default = mk-enable' "Neovim as the default $EDITOR";
    };
  config =
    { cfg, lib, ... }:
    let
      inherit (lib.rebellion) enabled;
    in
    {
      environment.sessionVariables = {
        EDITOR = lib.mkIf cfg.default.enable "nvim";
      };

      programs.neovim = enabled;
    };
}
