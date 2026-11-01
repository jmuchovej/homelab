{ den, ... }: {
  rbn.programs._.social = {
    _.beeper = {
      dock.key = "Beeper Desktop";
      dock.source = "hm";

      includes = [ (den.batteries.unfree [ "beeper" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [
          pkgs.beeper
          pkgs.beeper-bridge-manager
        ];
      };
    };

    _.zoom = {
      dock.key = "zoom.us";
      dock.source = "hm";

      includes = [ (den.batteries.unfree [ "zoom" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.zoom-us ];
      };

      # macos.homebrew.casks = [ "zoom" ];
    };

    _.zulip = {
      dock.key = "Zulip";
      dock.source = "brew";

      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.zulip ];
      };

      macos.homebrew.casks = [ "zulip" ];
    };
  };
}
