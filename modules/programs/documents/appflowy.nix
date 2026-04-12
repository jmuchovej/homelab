_: {
  rbn.programs._.documents._.appflowy = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.appflowy ];

        rebellion.dock.entries = [
          {
            name = "AppFlowy.app";
            source = "applications";
            group = "pkm";
            order = 450;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "appflowy" ];
      };
  };
}
