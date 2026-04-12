_: {
  rbn.programs._.creative = {
    provides.figma = {
      # TODO: no nixpkg named 'figma' for Linux
      homeManager = { };

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [ "figma" ];
        };
    };

    provides."3d-modeling" = {
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

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [
            "orcaslicer"
            "openscad@snapshot"
          ];
        };
    };

    provides.sketch = {
      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [ "sketch" ];
        };
    };
  };
}
