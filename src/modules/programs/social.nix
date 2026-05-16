_: {
  rbn.programs._.social = {
    provides.beeper = {
      dock.app = "Beeper Desktop.app";

      homeManager =
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            beeper-bridge-manager
          ];
        };

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [ "beeper" ];
        };
    };

    provides.zoom = {
      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.zoom-us ];
        };

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [ "zoom" ];
        };
    };

    provides.zulip = {
      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.zulip ];
        };

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [ "zulip" ];
        };
    };
  };
}
