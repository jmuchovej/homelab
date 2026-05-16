_: {
  rbn.programs._.editors._.neovim = {
    homeManager =
      { lib, pkgs, ... }:
      {
        programs.neovim = {
          enable = true;
          withRuby = false;
          withPython3 = false;
        };

        home.packages = with pkgs; [
          nvrh
        ];
      };

    nixos = _: {
      programs.neovim.enable = true;
    };
  };
}
