_: {
  rbn.programs._.editors._.neovim = {
    homeManager =
      { lib, pkgs, ... }:
      {
        programs.neovim.enable = true;

        home.packages = with pkgs; [
          nvrh
        ];
      };

    nixos =
      { lib, ... }:
      {
        programs.neovim.enable = true;
        environment.sessionVariables.EDITOR = lib.mkDefault "nvim";
      };
  };
}
