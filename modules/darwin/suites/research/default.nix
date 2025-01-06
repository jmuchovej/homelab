{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (lib.${namespace}) get-shared enabled;

  cfg = config.${namespace}.suites.research;
in {
  imports = [
    (get-shared "suites/research")
  ];

  config =
    mkIf cfg.enable {
    };
}
