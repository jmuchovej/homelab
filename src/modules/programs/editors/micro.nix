{
  rbn.programs._.editors._.micro.hm = { lib, ... }: {
    programs.micro = {
      enable = true;
      settings = {
        colorscheme = "catppuccin-macchiato";
      };
    };

    xdg.configFile."micro/colorschemes" = {
      source = lib.cleanSourceWith {
        filter =
          name: _type:
          let
            baseName = baseNameOf (toString name);
          in
          lib.hasSuffix ".micro" baseName;
        src = lib.cleanSource ./micro;
      };
      recursive = true;
    };
  };
}
