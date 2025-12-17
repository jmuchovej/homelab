{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.suites.research;
in
{
  imports = [
    (get-file "modules/common/suites/research.nix")
  ];

  config = mkIf cfg.enable {
  };
}
