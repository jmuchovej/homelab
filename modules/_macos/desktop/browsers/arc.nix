{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "desktop.arc";
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
        casks = [ "arc" ];
      };
    };
}
