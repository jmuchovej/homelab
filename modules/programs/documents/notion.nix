_: {
  rbn.programs._.documents._.notion = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.notion-app ];

        rebellion.dock.entries = [
          {
            name = "Notion.app";
            source = "applications";
            group = "pkm";
            order = 420;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [
          "notion"
          "notion-calendar"
        ];
      };
  };
}
