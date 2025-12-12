{
  options,
  config,
  lib,
  system,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.nix;
in
{
  imports = [ (get-file "modules/shared/nix.nix") ];

  config = mkIf cfg.enable {
    documentation = {
      man.generateCaches = mkDefault true;

      nixos = {
        enable = true;
        options = {
          warningsAreErrors = true;
          splitBuild = true;
        };
      };
    };

    nix = {
      daemonCPUSchedPolicy = "batch";
      daemonIOSchedClass = "idle";
      daemonIOSchedPriority = 7;

      gc = {
        dates = "Sun *-*-* 03:00";
      };

      optimise = {
        dates = [ "04:00" ];
      };

      settings = {
        experimental-features = [ "cgroups" ];
        use-cgroups = true;
      };
    };

    nixpkgs.hostPlatform = mkDefault system;
  };
}
