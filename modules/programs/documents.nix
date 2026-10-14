{ __findFile, den, ... }: {
  rbn.programs._.documents = {
    _.anytype = {
      dock.key = "Anytype";
      dock.source = "brew";

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
      dock.key = "AppFlowy";
      dock.source = "hm";

      includes = [ (den.batteries.unfree [ "appflowy" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.appflowy ];
      };
    };

    _.logseq = {
      dock.key = "Logseq";
      dock.source = "hm";

      includes = [ (den.batteries.insecure [ "electron-39.8.10" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.logseq ];
      };
    };

    _.notion = {
      dock.key = "Notion";
      dock.source = "hm";

      includes = [
        (den.batteries.unfree [ "notion-app" ])
        <rbn/programs/documents/notion/calendar>
      ];

      hm-macos = { pkgs, ... }: {
        home.packages = [ pkgs.notion-app ];
      };

      _.calendar = {
        dock.key = "Notion Calendar";
        dock.source = "brew";

        macos.homebrew.casks = [ "notion-calendar" ];
      };
    };

    _.obsidian = {
      dock.key = "Obsidian";
      dock.source = "hm";

      includes = [ (den.batteries.unfree [ "obsidian" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.obsidian ];
      };
    };

    _.pdfelement = {
      dock.key = "PDFelement";
      dock.source = "brew";

      macos.homebrew.casks = [ "pdfelement" ];
    };

    _.pdfexpert = {
      dock.key = "PDF Expert";
      dock.source = "brew";

      macos.homebrew.casks = [ "pdfexpert" ];
    };

    _.waypoints = {
      dock.key = "Waypoints";
      dock.source = "hm";

      hm = { pkgs, ... }: {
        nix.settings = {
          extra-substituters = [ "https://waypoints.cachix.org" ];
          extra-trusted-public-keys = [
            "waypoints.cachix.org-1:LzQKQwec0QZBJzLOVhO3j5oYBZbbzrHjuQYIOQLHZ8U="
          ];
        };

        # TODO: waypoints not in nixpkgs yet
        # home.packages = [ pkgs.waypoints ];
      };
    };
  };
}
