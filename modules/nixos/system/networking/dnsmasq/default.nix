{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkForce;

  cfg = config.${namespace}.system.networking;
in
{
  config = mkIf (cfg.enable && cfg.dns == "dnsmasq") {
    networking.networkmanager.dns = "dnsmasq";
    services.resolved.enable = mkForce false;
    services.dnsmasq = {
      enable = true;

      resolveLocalQueries = true;

      settings = {
        server = [
          "9.9.9.9"
          "149.112.112.112"
          "2620:fe::fe"
          "2620:fe::9"
        ];
      };
    };
  };
}
