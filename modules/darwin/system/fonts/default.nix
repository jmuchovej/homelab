{
  config,
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) get-shared;

  cfg = config.${namespace}.system.fonts;
in
{
  imports = [ (get-shared "system/fonts") ];

  config = mkIf cfg.enable {
    fonts = {
      packages = [ ] ++ cfg.fonts;
    };

    system.defaults = {
      NSGlobalDomain = {
        AppleFontSmoothing = 1;
      };
    };
  };
}
