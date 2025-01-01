{ config, lib, namespace, ... }: let
  inherit (lib) mkIf mkDefault;
  inherit (lib.${namespace}) get-shared enabled;

  cfg = config.${namespace}.suites.networking;
in
{
  imports = [
    (get-shared "suites/networking")
  ];

  config = mkIf cfg.enable {
  };
}
