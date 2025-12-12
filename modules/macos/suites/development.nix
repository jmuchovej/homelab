{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.suites.development;
in
{
  imports = [
    (get-file "modules/shared/suites/development.nix")
  ];

  config = mkIf cfg.enable {
    homebrew = {
      brews = [
        "cocoapods"
        "xcodegen"
        "xcodes"
      ];
      casks = [
        "flutter"
        "powershell"
      ];

      masApps = mkIf config.rebellion.homebrew.mas.enable {
        # FIXME: keeps trying to reinstall it
        "Xcode" = 497799835;
        "Playgrounds" = 1496833156;
      };
    };
  };
}
