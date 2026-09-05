{
  # Virtual keycode table consumed by `lib.rbn.macos.symbolic-hotkey`.
  flake-file.inputs.mac-keycodes = {
    flake = false;
    url = "file+https://gist.githubusercontent.com/eegrok/949034/raw/af13a5ec66ff5eb6fd15f28eea560554e31416a3/mac-keycodes";
  };

  rbn.system._.input.macos =
    { lib, ... }:
    let
      inherit (lib.rbn.macos) symbolic-hotkey;
    in
    {
      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
        userKeyMapping = [ ];
      };

      # What the fn/globe key does on its own. Needs a restart to take effect.
      system.defaults.hitoolbox.AppleFnUsageType = "Show Emoji & Symbols";

      system.defaults.magicmouse.MouseButtonMode = "OneButton";

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

      # Keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts).
      # Only non-default entries are listed; omitted IDs keep macOS defaults.
      system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
        # Screenshots: ⇧⌘3, ⌃⇧⌘3, ⇧⌘4, ⌃⇧⌘4, ⇧⌘5
        "28" = symbolic-hotkey false "shift + cmd + 3";
        "29" = symbolic-hotkey false "ctrl + shift + cmd + 3";
        "30" = symbolic-hotkey false "shift + cmd + 4";
        "31" = symbolic-hotkey false "ctrl + shift + cmd + 4";
        "184" = symbolic-hotkey false "shift + cmd + 5";
        # Input sources: ⌃Space (previous), ⌃⌥Space (next)
        "60" = symbolic-hotkey false "ctrl + ' '";
        "61" = symbolic-hotkey false "ctrl + alt + ' '";
      };
    };
}
