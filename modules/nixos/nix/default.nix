{ options, config, pkgs, lib, namespace, ... }:
let
  inherit (lib) types mkDefault mkIf mkEnableOption mkPackageOption mkOption;
  inherit (lib.${namespace} get-shared;

  cfg = config.${namespace}.nix;
in {
  imports = [ (get-shared "nix") ];

  config = mkIf cfg.enable {
    documentation = {
      man.generateCaches = mkDefault true;

      nixos = {
        enable  = true;
        options = {
          warningsAreErrors = true;
          splitBuild        = true;
        };
      };
    };

    nix = {
      daemonCPUSchedPolicy  = "batch";
      daemonIOSchedClass    = "idle";
      daemonIOSchedPriority = 7;

      gc = {
        dates = "Sun *-*-* 03:00";
      };

      optimise = {
        automatic = true;
        dates     = [ "04:00" ];
      };

      settings = {
        experimental-features = [ "cgroups" ];
        use-cgroups           = true;
      };
    }
  };
}
