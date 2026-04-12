_: {
  rbn.programs._.documents._.obsidian = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.obsidian ];

        rebellion.dock.entries = [
          {
            name = "Obsidian.app";
            source = "applications";
            group = "pkm";
            order = 410;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "obsidian" ];
      };
  };
}
