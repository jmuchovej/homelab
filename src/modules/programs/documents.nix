{
  rbn.programs._.documents = {
    _.anytype = {
      dock.app = "AnyType.app";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.anytype ];
      };

      macos.homebrew.casks = [ "anytype" ];
    };

    _.appflowy = {
      dock.app = "AppFlowy.app";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.appflowy ];
      };

      macos.homebrew.casks = [ "appflowy" ];
    };

    _.logseq = {
      dock.app = "Logseq.app";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.logseq ];
      };

      macos.homebrew.casks = [ "logseq" ];
    };

    _.notion = {
      dock.app = "Notion.app";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.notion-app ];
      };

      macos.homebrew.casks = [
        "notion"
        "notion-calendar"
      ];
    };

    _.obsidian = {
      dock.app = "Obsidian.app";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.obsidian ];
      };

      macos.homebrew.casks = [ "obsidian" ];
    };

    _.pdfelement = {
      macos.homebrew.casks = [ "pdfelement" ];
    };

    _.pdfexpert = {
      macos.homebrew.casks = [ "pdfexper" ];
    };

    _.waypoints = {
      os = {
        nix.settings.extra-substituters = [
          "https://waypoints.cachix.org"
        ];
        nix.settings.extra-trusted-public-keys = [
          "waypoints.cachix.org-1:LzQKQwec0QZBJzLOVhO3j5oYBZbbzrHjuQYIOQLHZ8U="
        ];
      };
      hm = { pkgs, ... }: {
        # TODO: waypoints not in nixpkgs yet
        # home.packages = [ pkgs.waypoints ];
      };
    };
  };
}
