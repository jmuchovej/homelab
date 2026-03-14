{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.starship";
  description = "starship";
  config = _: {
    programs.starship = {
      enable = true;
      package = pkgs.starship;
      presets = [
        "nerd-font-symbols"
        "jetpack"
      ];
    };
  };
}
