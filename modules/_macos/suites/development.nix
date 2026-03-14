{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.development";
  config =
    {
      config,
      lib,
      inputs,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (inputs) homebrew-fvm;
      brew = config.rebellion.homebrew;
    in
    {
      homebrew = mkIf brew.enable {
        brews = [
          "cocoapods"
          "xcodegen"
          "xcodes"
          "leoafarias/fvm/fvm"
        ];

        casks = [
          "flutter"
          "powershell"
          "beekeeper-studio"
        ];

        # TODO: mas installs are failing — re-enable once fixed
        # masApps = mkIf brew.mas.enable {
        #   "Playgrounds" = 1496833156;
        # };
      };

      nix-homebrew = mkIf brew.enable {
        taps."leoafarias/fvm" = homebrew-fvm;
      };
    };
}
