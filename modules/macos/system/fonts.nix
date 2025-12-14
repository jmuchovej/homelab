{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.system.fonts;
in
{
  imports = [ (get-file "modules/shared/system/fonts.nix") ];

  config = mkIf cfg.enable {
    system.defaults = {
      NSGlobalDomain = {
        AppleFontSmoothing = 1;
      };
    };
  };
}
