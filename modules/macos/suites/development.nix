{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;
  inherit (inputs) homebrew-fvm;

  cfg = config.rebellion.suites.development;
  brew = config.rebellion.homebrew;
in
{
  imports = [
    (get-file "modules/common/suites/development.nix")
  ];

  config = mkIf cfg.enable {
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

      masApps = mkIf brew.mas.enable {
        "Playgrounds" = 1496833156;
      };
    };

    nix-homebrew = mkIf brew.enable {
      taps."leoafarias/fvm" = homebrew-fvm;
    };
  };
}
