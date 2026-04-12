_: {
  rbn.system._.interface = {

    darwin =
      { host, ... }:
      let
        username = host.user.name;
      in
      {
        home-manager.users.${username}.home.file."Pictures/Screenshots/.keep".text = "";

        system.defaults.spaces.spans-displays = false;
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

          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
        };

        system.defaults.finder = {
          AppleShowAllExtensions = true;
          AppleShowAllFiles = true;
          CreateDesktop = true;
          FXDefaultSearchScope = "SCcf";
          FXEnableExtensionChangeWarning = false;
          FXPreferredViewStyle = "Nlsv";
          QuitMenuItem = true;
          ShowStatusBar = true;
          _FXShowPosixPathInTitle = true;
        };

        system.defaults.loginwindow = {
          GuestEnabled = false;
          SHOWFULLNAME = false;
        };

        system.defaults.menuExtraClock = {
          FlashDateSeparators = false;
          IsAnalog = false;
          Show24Hour = true;
          ShowAMPM = false;
          ShowDayOfMonth = true;
          ShowDayOfWeek = true;
          ShowDate = 1;
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
          location = "/Users/${username}/Pictures/Screenshots/";
          type = "png";
        };

        system.defaults.universalaccess = {
          reduceMotion = false;
          reduceTransparency = true;
        };
      };
  };
}
