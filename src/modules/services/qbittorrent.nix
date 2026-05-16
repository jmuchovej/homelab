{ __findFile, ... }:
{
  rbn.services._.qbittorrent = {
    nixos =
      { config, pkgs, ... }:
      {
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
      };

    includes = [
      (<rbn/mesh/register> {
        name = "qbittorrent";
        port = 9797;
        authed = true;
        healthcheck = "/";
        authentik = {
          name = "qBittorrent";
          type = "proxy";
          group = "Media Management";
          access = [ "media-managers" ];
          icon = "qbittorrent";
          skip-paths = "/api/*";
          basic-auth = {
            username = "servarr-username";
            password = "servarr-password";
          };
        };
      })
    ];
  };
}
