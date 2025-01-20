{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.${namespace}) enabled;
in {
  ${namespace} = {
    nix = enabled;
    suites = {
      common = enabled;
      desktop = enabled;
      development = enabled;
      research = enabled;
      networking = enabled;
    };

    homebrew.mas = enabled;
  };

  environment.systemPath = ["/opt/homebrew/bin"];

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

  nix.settings = {
    cores = 10;
    max-jobs = 4;
  };

  security.pam.enableSudoTouchIdAuth = true;
  system.startup.chime = false;

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = 5;
  # ======================== DO NOT CHANGE THIS ========================
}
