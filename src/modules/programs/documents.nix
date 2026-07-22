{
  rbn.programs._.documents = {
    _.anytype = {
      dock.app = "AnyType.app";

      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.anytype ];
        };

      darwin.homebrew.casks = [ "anytype" ];
    };

    _.appflowy = {
      dock.app = "AppFlowy.app";

      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.appflowy ];
        };

      darwin.homebrew.casks = [ "appflowy" ];
    };

    _.logseq = {
      dock.app = "Logseq.app";

      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.logseq ];
        };

      darwin.homebrew.casks = [ "logseq" ];
    };

    _.notion = {
      dock.app = "Notion.app";

      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.notion-app ];
        };

      darwin.homebrew.casks = [
        "notion"
        "notion-calendar"
      ];
    };

    _.obsidian = {
      dock.app = "Obsidian.app";

      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.obsidian ];
        };

      darwin.homebrew.casks = [ "obsidian" ];
    };

    _.pdfelement = {
      darwin.homebrew.casks = [ "pdfelement" ];
    };

    _.pdfexpert = {
      darwin.homebrew.casks = [ "pdfexper" ];
    };

    _.waypoints.homeManager = { pkgs, ... }: {
      # TODO: waypoints not in nixpkgs yet
      home.packages = [ ];
    };
  };
}
