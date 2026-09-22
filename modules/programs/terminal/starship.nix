{
  rbn.programs._.terminal._.starship = {
    hm = _: {
      programs.starship = {
        enable = true;
        presets = [
          "nerd-font-symbols"
          # "bracketed-segments"
          "no-runtime-versions"
          # "jetpack"
        ];
      };
    };

    nixos = _: {
      programs.starship = {
        enable = true;
        presets = [
          "nerd-font-symbols"
          "no-runtime-versions"
          # "jetpack"
        ];
      };
    };
  };
}
