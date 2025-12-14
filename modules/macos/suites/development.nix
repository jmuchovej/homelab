{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.suites.development;
  brew = config.rebellion.homebrew;
in
{
  imports = [
    (get-file "modules/shared/suites/development.nix")
  ];

  config = mkIf cfg.enable {
    homebrew = mkIf brew.enable {
      brews = [
        "cocoapods"
        "xcodegen"
        "xcodes"
      ];

      casks = [
        "flutter"
        "powershell"
      ];

      masApps = mkIf brew.mas.enable {
        "Playgrounds" = 1496833156;
      };
    };
  };
}
