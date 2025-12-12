{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.rebellion) get-file enabled;

  cfg = config.rebellion.suites.research;
in
{
  imports = [
    (get-file "modules/shared/suites/research/default.nix")
  ];

  config = mkIf cfg.enable {
  };
}
