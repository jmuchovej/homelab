{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (inputs)
    homebrew-core
    homebrew-cask
    homebrew-bundle
    homebrew-services
    ;

  cfg = config.rebellion.homebrew;
in
{
  config = mkIf cfg.enable {
    nix-homebrew = {
      enable = true;
      user = config.rebellion.user.name;

      taps = {
        "homebrew/core" = homebrew-core;
        "homebrew/cask" = homebrew-cask;
        "homebrew/bundle" = homebrew-bundle;
        "homebrew/services" = homebrew-services;
      };
    };

    homebrew = {
      brews = [ ];
    };
  };
}
