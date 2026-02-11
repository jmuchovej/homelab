{ lib, ... }@args:
lib.rebellion.mk-module args {
  namespace = "system";
  imports = [ (lib.rebellion.get-file "modules/common/system/nix.nix") ];
  config =
    { lib, ... }:
    {
      documentation.nixos = {
        enable = true;
        options = {
          warningsAreErrors = true;
          splitBuild = true;
        };
      };

      nix = {
        daemonCPUSchedPolicy = "batch";
        daemonIOSchedClass = "idle";
        daemonIOSchedPriority = 7;

        gc.dates = [ "weekly" ];
        optimise.dates = [ "04:00" ];

        settings = {
          auto-optimise-store = lib.mkDefault true;
          log-lines = 50;
          http-connections = 50;
          experimental-features = [ "cgroups" ];
          use-cgroups = true;
        };
      };
    };
}
