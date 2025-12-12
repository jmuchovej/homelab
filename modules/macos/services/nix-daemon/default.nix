{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) types mkIf mkEnableOption;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.services.nix-daemon;
in {
  options.rebellion.services.nix-daemon = {
    enable = mkEnableOption "nix-daemon"; # { default = true; };
  };

  config = mkIf cfg.enable {
    services.nix-daemon = enabled;
  };
}
