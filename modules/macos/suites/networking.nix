{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.rebellion) get-file enabled;

  cfg = config.rebellion.suites.networking;
in
{
  imports = [
    (get-file "modules/shared/suites/networking.nix")
  ];

  config = mkIf cfg.enable {
  };
}
