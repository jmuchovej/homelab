{ __findFile, den, ... }: {
  rbn.programs._.creative = {
    _.figma = {
      dock.key = "Figma";
      dock.source = "brew";

      # TODO: no nixpkg named 'figma' for Linux
      hm = _: { };

      macos.homebrew.casks = [ "figma" ];
    };

    _."3d-modeling" = {
      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.orca-slicer ];
      };

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.openscad-unstable ];
      };

      macos.homebrew.casks = [ "orcaslicer" ];
    };

    _.design = {
      includes = [
        <rbn/programs/creative/design/sketch>
        <rbn/programs/creative/design/affinity>
      ];

      _.sketch = {
        dock.key = "Sketch";
        dock.source = "hm";

        includes = [ (den.batteries.unfree [ "sketch" ]) ];

        hm-macos = { pkgs, ... }: {
          home.packages = [ pkgs.rbn.sketch ];
        };
      };

      _.affinity = {
        dock.key = "Affinity";
        dock.source = "hm";

        includes = [ (den.batteries.unfree [ "affinity" ]) ];

        hm-macos = { pkgs, ... }: {
          home.packages = [ pkgs.rbn.affinity ];
        };
      };
    };
  };
}
