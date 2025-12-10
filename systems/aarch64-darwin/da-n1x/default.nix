{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.${namespace}) enabled disabled;
in {
  ${namespace} = {
    nix = disabled;
    suites = {
      common = enabled;
      desktop = enabled;
      development = enabled;
      research = enabled;
      networking = enabled;
    };

    homebrew.mas = enabled;
  };

  nix.enable = false;

  environment.systemPath = ["/opt/homebrew/bin"];

  system.primaryUser = config.${namespace}.user.name;

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

  # nix.settings = {
  #   cores = 10;
  #   max-jobs = 4;
  # };

  security.pam.services.sudo_local.touchIdAuth =  true;
  system.startup.chime = false;

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = 5;
  # ======================== DO NOT CHANGE THIS ========================
}
