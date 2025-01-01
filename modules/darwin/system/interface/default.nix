{ config, lib, namespace, pkgs, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.system.interface;
in
{
  options.${namespace}.system.interface = {
    enable = mkEnableOption "macOS interface customizations";
  };

  config = mkIf cfg.enable {
    ${namespace}.home.file = {
      "Pictures/Screenshots/.keep".text = "";
    };

    system.defaults = {
      CustomSystemPreferences = {
        finder = {
          DisableAllAnimations = true;
          ShowExternalHardDrivesOnDesktop = false;
          ShowHardDrivesOnDesktop = false;
          ShowMountedServersOnDesktop = false;
          ShowRemovableMediaOnDesktop = false;
          _FXSortFoldersFirst = true;
        };

        NSGlobalDomain = {
          AppleAccentColor = 1;
          AppleHighlightColor = "0.65098 0.85490 0.58431";
          AppleSpacesSwitchOnActivate = false;
          WebKitDeveloperExtras = true;
        };
      };

      # dock settings
      dock = {
        autohide                = true;
        autohide-delay          = 0.0;
        autohide-time-modifier  = 1.0;
        mineffect               = "scale";
        minimize-to-application = true;
        mouse-over-hilite-stack = true;
        mru-spaces              = false;
        orientation             = "bottom";
        show-process-indicators = true;
        show-recents            = false;
        showhidden              = false;
        static-only             = false;
        tilesize                = 50;

        # Hot corners
        # Possible values:
        #  1: no-op
        #  2: Mission Control
        #  3: Show application windows
        #  4: Desktop
        #  5: Start screen saver
        #  6: Disable screen saver
        #  7: Dashboard
        # 10: Put display to sleep
        # 11: Launchpad
        # 12: Notification Center
        # 13: Lock Screen
        # 14: Quick Notes
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
        wvous-bl-corner = 1;
        wvous-br-corner = 1;

        persistent-apps = [
          "/System/Applications/System Settings.app"
          "/System/Applications/Utilities/Activity Monitor.app"
          { spacer.small = true; }
          "/System/Applications/Messages.app"
          # "${pkgs.beeper}/Applications/Beeper.app"
          "${pkgs.spotify}/Applications/Spotify.app"
          # "${pkgs.caprine-bin}/Applications/Caprine.app"
          # "${pkgs.element-desktop}/Applications/Element.app"
          # "/Applications/Microsoft Teams.app"
          # "${pkgs.discord}/Applications/Discord.app"
          # "/Applications/Thunderbird.app"
          { spacer.small = true; }
          "${pkgs.arc-browser}/Applications/Arc.app"
          "/Applications/Firefox Developer Edition.app"
          "/Applications/Safari.app"
          { spacer.small = true; }
          "/Applications/Setapp/Craft.app"
          "/Applications/Notion.app"
          "/Applications/Notion Calendar.app"
          "${pkgs.logseq}/Applications/Logseq.app"
          "${pkgs.appflowy}/Applications/Appflowy.app"
          { spacer.small = true; }
          "${pkgs.vscode}/Applications/Visual Studio Code.app"
          "${pkgs.bruno}/Applications/Bruno.app"
          { spacer.small = true; }
          "${pkgs.wezterm}/Applications/WezTerm.app"
          "${pkgs.rio}/Applications/Rio.app"
        ];
      };

      # file viewer settings
      finder = {
        AppleShowAllExtensions          = true;
        AppleShowAllFiles               = true;
        CreateDesktop                   = true;
        FXDefaultSearchScope            = "SCcf";
        FXEnableExtensionChangeWarning  = false;
        # NOTE: Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
        FXPreferredViewStyle            = "Nlsv";
        QuitMenuItem                    = true;
        ShowStatusBar                   = true;
        _FXShowPosixPathInTitle         = true;
      };

      # login window settings
      loginwindow = {
        # disable guest account
        GuestEnabled = false;
        # show name instead of username
        SHOWFULLNAME = false;
      };

      menuExtraClock = {
        FlashDateSeparators = false;
        IsAnalog            = true;
        Show24Hour          = true;
        ShowAMPM            = false;
        ShowDayOfMonth      = true;
        ShowDayOfWeek       = true;
        ShowDate            = 1;  # Always
        ShowSeconds         = true;
      };

      NSGlobalDomain = {
        "com.apple.sound.beep.feedback"     = 0;
        "com.apple.sound.beep.volume"       = 0.0;
        AppleShowAllExtensions              = true;
        AppleShowScrollBars                 = "Automatic";
        NSAutomaticWindowAnimationsEnabled  = false;
        _HIHideMenuBar                      = false;
      };

      screencapture = {
        disable-shadow = false;
        location = "/Users/${config.${namespace}.user.name}/Pictures/Screenshots/";
        type = "png";
      };

      spaces.spans-displays = !config.services.yabai.enable;

      universalaccess = {
        reduceMotion = false;
      };
    };
  };
}
