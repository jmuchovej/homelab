_: {
  rbn.programs._.documents._.obsidian = {
    dock.app = "Obsidian.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.obsidian ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "obsidian" ];
      };
  };
}
