{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "desktop.onepassword";
  config =
    {
      cfg,
      lib,
      config,
      ...
    }:
    let
      brew = config.rebellion.homebrew;
    in
    {
      homebrew = lib.mkIf brew.enable {
        # TODO contrib support for 1Password via Nix
        casks = [ "1password" ];

        masApps = lib.mkIf brew.mas.enable {
          "1Password for Safari" = 1569813296;
        };
      };
    };
}
