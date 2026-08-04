{ den, ... }: {
  rbn.programs._.social = {
    _.beeper = {
      dock.app = "Beeper Desktop.app";

      includes = [
        (den.batteries.unfree [ "beeper" ])
      ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.beeper-bridge-manager ];
      };

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.beeper ];
      };

      macos.homebrew.casks = [ "beeper" ];
    };

    _.zoom = {
      dock.app = "zoom.us.app";

      includes = [
        (den.batteries.unfree [ "zoom" ])
      ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.zoom-us ];
      };

      # macos.homebrew.casks = [ "zoom" ];
    };

    _.zulip = {
      dock.app = "Zulip.app";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.zulip ];
      };

      macos.homebrew.casks = [ "zulip" ];
    };
  };
}
