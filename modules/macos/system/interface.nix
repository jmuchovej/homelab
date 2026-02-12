{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "system.interface";
  config =
    { cfg, config, ... }:
    {
      rebellion.home.file = {
        "Pictures/Screenshots/.keep".text = "";
      };

      # Spaces
      system.defaults.spaces.spans-displays = false;
      # TODO once trying out `yabai`, look into this
      # system.defaults.spaces.spans-displays = !config.rebellion.services.yabai.enable;
      system.defaults.NSGlobalDomain.AppleSpacesSwitchOnActivate = false;

      system.defaults.CustomSystemPreferences = {
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
          WebKitDeveloperExtras = true;
        };
      };

      # dock settings
      system.defaults.dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 1.0;
        mineffect = "suck";
        minimize-to-application = true;
        mouse-over-hilite-stack = true;
        mru-spaces = false;
        orientation = "bottom";
        show-process-indicators = true;
        show-recents = true;
        showhidden = true;
        static-only = false;
        tilesize = 48;

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
      };

      # file viewer settings
      system.defaults.finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        CreateDesktop = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        # NOTE: Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
        FXPreferredViewStyle = "Nlsv";
        QuitMenuItem = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
      };

      # login window settings
      system.defaults.loginwindow = {
        # disable guest account
        GuestEnabled = false;
        # show name instead of username
        SHOWFULLNAME = false;
      };

      system.defaults.menuExtraClock = {
        FlashDateSeparators = false;
        IsAnalog = false;
        Show24Hour = true;
        ShowAMPM = false;
        ShowDayOfMonth = true;
        ShowDayOfWeek = true;
        ShowDate = 1; # Always
        ShowSeconds = true;
      };

      system.defaults.NSGlobalDomain = {
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.sound.beep.volume" = 0.0;
        AppleShowAllExtensions = true;
        AppleShowScrollBars = "Automatic";
        NSAutomaticWindowAnimationsEnabled = false;
        _HIHideMenuBar = false;
      };

      system.defaults.screencapture = {
        disable-shadow = false;
        location = "/Users/${config.rebellion.user.name}/Pictures/Screenshots/";
        type = "png";
      };

      system.defaults.universalaccess = {
        reduceMotion = false;
        reduceTransparency = true;
      };
    };
}
