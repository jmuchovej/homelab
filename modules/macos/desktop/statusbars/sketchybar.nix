{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "desktop.statusbars.sketchybar";
  options =
    { lib, ... }:
    {
      logFile =
        lib.rebellion.mkopt lib.types.str "/Users/john/Library/Logs/sketchybar.log"
          "Path to sketchybar's logs.";
    };
  config =
    { cfg, ... }:
    {
      rebellion.home.extraOptions = {
        home.shellAliases = {
          restart-sketchybar = ''launchctl kickstart -k gui/"$(id -u)"/org.nixos.sketchybar'';
        };
      };

      homebrew = {
        # brews = [ "cava" ];
        # casks = [ "background-music" ];
      };

      # services.sketchybar = { ... };
    };
}
