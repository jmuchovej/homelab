{
  rbn.programs._.creative = {
    _.figma = {
      # TODO: no nixpkg named 'figma' for Linux
      homeManager = { };

      darwin.homebrew.casks = [ "figma" ];
    };

    _."3d-modeling" = {
      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux (
            with pkgs;
            [
              openscad-unstable
              orcaslicer
            ]
          );
        };

      darwin.homebrew.casks = [
        "orcaslicer"
        "openscad@snapshot"
      ];
    };

    _.design = {
      darwin.homebrew.casks = [
        "sketch"
        "affinity"
      ];
    };
  };
}
