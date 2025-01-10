{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.system.input;
in {
  options.${namespace}.system.input = {
    enable = mkEnableOption "macOS input customizations";
  };

  config = mkIf cfg.enable {
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
      # swapLeftCommandAndLeftAlt = true;
      # https://developer.apple.com/library/content/technotes/tn2450/_index.html
      userKeyMapping = [];
    };

    # trackpad settings
    system.defaults.trackpad = {
      # silent clicking = 0, default = 1
      ActuationStrength = 0;
      # enable tap to click
      Clicking = true;
      # Enable tap to drag
      # Dragging = true;
      # firmness level, 0 = lightest, 2 = heaviest
      FirstClickThreshold = 1;
      # firmness level for force touch
      SecondClickThreshold = 1;
      # don't allow positional right click
      TrackpadRightClick = true;
      # three finger drag
      TrackpadThreeFingerDrag = true;
    };

    system.defaults.".GlobalPreferences" = {
      "com.apple.mouse.scaling" = 1.0;
    };

    system.defaults.NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;

      KeyRepeat = 2;
      InitialKeyRepeat = 68;

      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    system.defaults.CustomSystemPreferences = {
        # "com.apple.symbolichotkeys" = {
        #   # Turn off Spotlight shortcut keys
        #   "com.apple.symbolichotkeys.AppleSymbolicHotKeys.64.enabled" = false;
        # };
    };
  };
}
