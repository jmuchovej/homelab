{
  rbn.programs._.editors._.neovim = {
    hm = { pkgs, ... }: {
      programs.neovim = {
        enable = true;
        withRuby = false;
        withPython3 = false;
      };

      home.packages = [ pkgs.nvrh ];
    };

    nixos = _: {
      programs.neovim.enable = true;
    };
  };
}
