{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.rebellion.desktop.statusbars.sketchybar;
in
{
  options.rebellion.desktop.statusbars.sketchybar = {
    enable = mkEnableOption "sketchybar";
    logFile = mkOption {
      type = str;
      default = "/Users/john/Library/Logs/sketchybar.log";
      description = "Path to sketchybar's logs.";
    };
  };

  config = mkIf cfg.enable {
    rebellion.home.extraOptions = {
      home.shellAliases = {
        restart-sketchybar = ''launchctl kickstart -k gui/"$(id -u)"/org.nixos.sketchybar'';
      };
    };

    homebrew = {
      # brews = [ "cava" ];
      # casks = [ "background-music" ];
    };

    # services.sketchybar = {
    #   enable = true;
    #   package = pkgs.sketchybar;
    #   inherit (cfg) logFile;

    #   extraPackages = with pkgs; [
    #     coreutils
    #     curl
    #     gh
    #     gnugrep
    #     gnused
    #     jq
    #     lua5_4
    #     wttrbar
    #     # pkgs.rebellion.sketchyhelper
    #     # pkgs.rebellion.dynamic-island-helper
    #   ];

    # TODO: need to update nixpkg to support complex configurations
    # config = ''
    #
    # '';
    # };
  };
}
