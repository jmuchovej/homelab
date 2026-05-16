_: {
  rbn.programs._.editors._.micro.homeManager =
    { lib, ... }:
    let
      inherit (lib) cleanSourceWith cleanSource hasSuffix;
    in
    {
      programs.micro = {
        enable = true;
        settings = {
          colorscheme = "catppuccin-macchiato";
        };
      };

      xdg.configFile."micro/colorschemes" = {
        source = cleanSourceWith {
          filter =
            name: _type:
            let
              baseName = baseNameOf (toString name);
            in
            hasSuffix ".micro" baseName;
          src = cleanSource ./micro;
        };
        recursive = true;
      };
    };
}
