{ den, ... }:
{
  rbn.programs._.creative = {
    _.figma = {
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
        (den.batteries.unfree [
          "sketch"
          "affinity"
        ])
      ];

      hm-macos = { pkgs, ... }: {
        home.packages = [
          pkgs.rbn.sketch
          pkgs.rbn.affinity
        ];
      };
    };
  };
}
