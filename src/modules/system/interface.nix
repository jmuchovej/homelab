{
  rbn.system._.interface.macos =
    { host, ... }:
    let
      username = host.primary-user.name;
    in
    {
      home-manager.users.${username}.home.file."Pictures/Screenshots/.keep".text = "";

      system.defaults.spaces.spans-displays = false;
      system.defaults.NSGlobalDomain.AppleSpacesSwitchOnActivate = false;

      # Keys nix-darwin has no typed option for. These are user preferences, so
      # they must go through `CustomUserPreferences` with full domain names;
      # `CustomSystemPreferences` writes root's plists and never reaches the
      # login user.
      system.defaults.CustomUserPreferences = {
        "com.apple.finder".DisableAllAnimations = true;

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
        ShowExternalHardDrivesOnDesktop = false;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = false;
        ShowRemovableMediaOnDesktop = false;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
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

      # Stage Manager stays off; window tiling on, without margins.
      system.defaults.WindowManager = {
        GloballyEnabled = false;
        AutoHide = false;
        AppWindowGroupingBehavior = true;
        HideDesktop = true;
        StageManagerHideWidgets = false;

        EnableStandardClickToShowDesktop = true;
        StandardHideDesktopIcons = false;
        StandardHideWidgets = false;

        EnableTilingByEdgeDrag = true;
        EnableTopTilingByEdgeDrag = true;
        EnableTilingOptionAccelerator = true;
        EnableTiledWindowMargins = false;
      };

      # Only the battery toggle is declared: nix-darwin can express the other
      # menu bar items solely as always-shown or always-hidden, never
      # "when active", which is what they are set to here.
      system.defaults.controlcenter.BatteryShowPercentage = true;

      system.defaults.screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      system.defaults.ActivityMonitor = {
        OpenMainWindow = true;
        ShowCategory = 100;
      };

      system.defaults.LaunchServices.LSQuarantine = true;

      system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
    };
}
