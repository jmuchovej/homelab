{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.qbittorrent";
  config =
    {
      config,
      lib,
      pkgs,
      hostname,
      datacenter,
      ...
    }:
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
              BypassAuthSubnetWhitelist = true;
              AuthSubnetWhitelist = "10.69.0.0/16";
              # NOTE: added b/c SOPS templates + crudini doesn't work since the
              #   qBittorrent.conf is read-only... >.>
              Username = "servarr";
              Password_PBKDF2 = "@ByteArray(hLn8qRJjzDennq46o+5UsQ==:DR/FTvFcELQeRuAqNA0rpWTzV6v+oFEvcDGw4TBo2YXfjr8M1TrcXMNTXJr/zqQuIICyLS/aTjOq4crRHOMH9Q==)";
            };
            BitTorrent.Session = {
              Interface = "proton0";
              InterfaceName = "proton0";
            };
            LegalNotice.Accepted = true;
          };
        };

        systemd.services.qbittorrent.serviceConfig.SupplementaryGroups = [ "proton" ];
      }
      (
        let
          inherit (lib.rebellion) attrs;
          inherit (lib.rebellion.network)
            with-consul
            mk-authd-traefik-service
            mk-healthcheck
            mk-authentik
            ;
          service = attrs.merge-deep [
            (mk-authd-traefik-service {
              inherit hostname datacenter;
              name = "qbittorrent";
              port = config.services.qbittorrent.webuiPort;
              public = true;
            })
            {
              svc.config.loadBalancer.passHostHeader = false;
            }
          ];
          healthcheck = mk-healthcheck service {
            route = "/"; # Root path doesn't require auth
          };
          authentik-tags = mk-authentik service {
            name = "qBittorrent";
            type = "proxy";
            group = "Media Management";
            access = [ "media-managers" ];
            icon = "qbittorrent";
            skip-paths = "/api/*";
            basic-auth.username = "servarr-username";
            basic-auth.password = "servarr-password";
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
            tags = authentik-tags;
          }
        )
      )
    ];
}
