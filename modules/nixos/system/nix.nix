{
  config,
  lib,
  system,
  ...
}:
let
  inherit (lib) mkDefault mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.system.nix;
in
{
  imports = [ (get-file "modules/common/system/nix.nix") ];

  config = mkIf cfg.enable {
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

      optimise.dates = [ "04:00" ];

      settings = {
        auto-optimise-store = mkDefault true;
        log-lines = 50;
        http-connections = 50;
        experimental-features = [ "cgroups" ];
        use-cgroups = true;
      }; # // (lib.optionalAttrs config.rebellion.apps.tools.direnv.enable {
      #   keep-outputs      = true;
      #   keep-derivations  = true;
      # });
    };
  };
}
