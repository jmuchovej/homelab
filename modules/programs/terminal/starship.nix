_: {
  rbn.programs._.terminal._.starship = {
    homeManager =
      { pkgs, ... }:
      {
        programs.starship = {
          enable = true;
          package = pkgs.starship;
        };
      };

    nixos = {
      programs.starship = {
        enable = true;
        presets = [
          "nerd-font-symbols"
          "jetpack"
        ];
      };
    };
  };
}
