_: {
  rbn.programs._.documents._.appflowy = {
    dock.app = "AppFlowy.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.appflowy ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "appflowy" ];
      };
  };
}
