_: {
  rbn.programs._.documents._.notion = {
    dock.app = "Notion.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.notion-app ];
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
