{ lib, ... }@args:
lib.rebellion.mk-module args {
  namespace = "system";
  config =
    { config, lib, ... }:
    let
      username = config.rebellion.user.name;
      hmBrew = config.home-manager.users.${username}.rebellion.homebrew;
      brew = config.rebellion.homebrew;
    in
    lib.mkIf brew.enable {
      homebrew = {
        inherit (hmBrew) casks;
        inherit (hmBrew) brews;
        masApps = lib.mkIf brew.mas.enable hmBrew.mas-apps;
      };
    };
}
