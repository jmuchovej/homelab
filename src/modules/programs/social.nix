{
  rbn.programs._.social = {
    _.beeper = {
      dock.app = "Beeper Desktop.app";

      homeManager =
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            beeper-bridge-manager
          ];
        };

      darwin.homebrew.casks = [ "beeper" ];
    };

    _.zoom = {
      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.zoom-us ];
        };

      darwin.homebrew.casks = [ "zoom" ];
    };

    _.zulip = {
      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.zulip ];
        };

      darwin.homebrew.casks = [ "zulip" ];
    };
  };
}
