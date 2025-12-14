{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.suites.desktop;
in
{
  imports = [
    (get-file "modules/common/suites/desktop.nix")
  ];

  config = mkIf cfg.enable {
  };
}
