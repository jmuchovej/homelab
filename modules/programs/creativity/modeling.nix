_: {
  rbn.programs._.creativity._.modeling = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux (
          with pkgs;
          [
            openscad-unstable
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
}
