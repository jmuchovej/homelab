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

      (
        let
          inherit (lib.rebellion) merge-attrs;
          inherit (lib.rebellion.network) with-consul mk-traefik-service mk-healthcheck;
          service = merge-attrs [
            (mk-traefik-service {
              inherit hostname;
              name = "qbittorrent";
              port = config.services.qbittorrent.webuiPort;
              public = false;
            })
            {
              svc.config.loadBalancer.passHostHeader = false;
            }
          ];
          healthcheck = mk-healthcheck service {
            router = "/"; # Root path doesn't require auth
          };
        in
        with-consul config (service // { checks = [ healthcheck ]; })
      )
    ];
}
