{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.system.input;
in
{
  options.rebellion.system.input = {
    enable = mkEnableOption "macOS input customizations";
  };

  config = mkIf cfg.enable {
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
      # swapLeftCommandAndLeftAlt = true;
      # https://developer.apple.com/library/content/technotes/tn2450/_index.html
      userKeyMapping = [ ];
    };

    # trackpad settings
    system.defaults.trackpad = {
      ActuateDetents = true;
      ActuationStrength = 0;
      Clicking = true;
      DragLock = false;
      Dragging = false;
      FirstClickThreshold = 1;
      ForceSuppressed = false;
      SecondClickThreshold = 1;
      TrackpadCornerSecondaryClick = 0;
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerPinchGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
      TrackpadMomentumScroll = true;
      TrackpadPinch = true;
      TrackpadRightClick = true;
      TrackpadRotate = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerTapGesture = 2;
      TrackpadThreeFingerVertSwipeGesture = 2;
      TrackpadTwoFingerDoubleTapGesture = true;
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
    };

    system.defaults.dock = {
      showAppExposeGestureEnabled = false;
      showMissionControlGestureEnabled = true;
      showLaunchpadGestureEnabled = false;
      showDesktopGestureEnabled = true;
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
