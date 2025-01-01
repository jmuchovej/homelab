{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) get-shared;

  cfg = config.${namespace}.suites.development;
in
{
  imports = [
    (get-shared "suites/development")
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

      masApps = mkIf config.${namespace}.homebrew.mas.enable {
        # FIXME: keeps trying to reinstall it
        "Xcode"       = 497799835;
        "Playgrounds" = 1496833156;
      };
    };
  };
}
