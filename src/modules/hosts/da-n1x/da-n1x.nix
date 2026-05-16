{ __findFile, ... }:
{
  den.hosts.aarch64-darwin.da-n1x = {
    primary-user = {
      name = "john";
      email = "john@jm0.io";
      full-name = "John Muchovej";
      uid = 501;
    };
    homebrew = {
      enable = true;
      mas.enable = true;
    };
    notunes.enable = true;
  };

  den.aspects.da-n1x = {
    includes = [
      <rbn/suite/desktop>
      <rbn/suite/development>
      <rbn/programs/media/spotify>
      <rbn/system/networking/wg-holonet>
      <rbn/services/zerotier>
    ];

    darwin = {
      networking = {
        computerName = "John's Macbook Pro";
        hostName = "da-n1x";
        localHostName = "da-n1x";
        knownNetworkServices = [
          "Anker 563"
          "Anker 564"
          "UGreen 50737"
          "Wi-Fi"
          "Thunderbolt Bridge"
        ];
      };

      security.pam.services.sudo_local.touchIdAuth = true;

      system.startup.chime = false;
      system.stateVersion = 5;
    };
  };
}
