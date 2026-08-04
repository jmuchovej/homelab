{ den, ... }: {
  rbn.programs._.documents = {
    _.anytype = {
      dock.app = "AnyType.app";

      includes = [
        (den.batteries.unfree [
          "anytype"
          # "anytype-heart"
        ])
      ];

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.anytype ];
      };

      hm = { pkgs, ... }: {
        home.packages = with pkgs; [
          anytype-cli
          # anytype-heart
        ];
      };

      macos.homebrew.casks = [ "anytype" ];
    };

    _.appflowy = {
      dock.app = "AppFlowy.app";

      includes = [ (den.batteries.unfree [ "appflowy" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.appflowy ];
      };
    };

    _.logseq = {
      includes = [ (den.batteries.insecure [ "electron-39.8.10" ]) ];

      dock.app = "Logseq.app";

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.logseq ];
      };
    };

    _.notion = {
      dock.app = "Notion.app";

      includes = [ (den.batteries.unfree [ "notion-app" ]) ];

      hm-macos = { pkgs, ... }: {
        home.packages = [ pkgs.notion-app ];
      };

      macos.homebrew.casks = [
        "notion-calendar"
      ];
    };

    _.obsidian = {
      dock.app = "Obsidian.app";

      includes = [ (den.batteries.unfree [ "obsidian" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.obsidian ];
      };
    };

    _.pdfelement = {
      dock.app = "Wondershare PDFelement.app";
      macos.homebrew.casks = [ "pdfelement" ];
    };

    _.pdfexpert = {
      dock.app = "PDFExpert.app";
      macos.homebrew.casks = [ "pdfexpert" ];
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
