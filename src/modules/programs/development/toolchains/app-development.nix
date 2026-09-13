## Mobile/desktop app stack: the framework toolchains plus the platform SDKs
## (Android Studio, Xcode tooling) that both of them need.
{ __findFile, den, ... }:
{
  rbn.programs._.development._.toolchains._.app-development = {
    includes = [
      (den.batteries.unfree [ "android-studio" ])
      <rbn/programs/development/toolchains/flutter>
      <rbn/programs/development/toolchains/tauri>
      <rbn/programs/development/languages/kotlin>
      <rbn/programs/development/languages/swift>
    ];

    hm-linux = { pkgs, ... }: {
      home.packages = [ pkgs.android-studio ];
    };

    macos.homebrew = {
      brews = [
        "cocoapods"
        "xcodegen"
        "xcodes"
      ];
      casks = [ "android-studio" ];
    };
  };
}
