{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.qbittorrent";
  config =
    {
      config,
      lib,
      pkgs,
      hostname,
      ...
    }:
    let
      inherit (lib.rebellion) merge-attrs;
      inherit (lib.rebellion.network) mk-traefik-service with-consul;
    in
    lib.mkMerge [
      {
        rebellion.services.proton-vpn.enable = true;

        services.qbittorrent = {
          enable = true;
          openFirewall = true;
          webuiPort = 9797;
          serverConfig = {
            Preferences.WebUI = {
              Address = "*";
              AlternativeUIEnabled = true;
              RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
            };
            BitTorrent.Session = {
              Interface = "proton0";
              InterfaceName = "proton0";
            };
          };
        };
      }

      (with-consul config (merge-attrs [
        (mk-traefik-service {
          inherit hostname;
          name = "qbittorrent";
          port = config.services.qbittorrent.webuiPort;
          public = false;
          healthcheck = "/"; # Root path doesn't require auth
        })
        {
          svc.config.loadBalancer.passHostHeader = false;
        }
      ]))
    ];
}
