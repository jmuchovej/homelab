{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) types mkIf mkEnableOption;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.services.nix-daemon;
in
{
  options.${namespace}.services.nix-daemon = {
    enable = mkEnableOption "nix-daemon"; # { default = true; };
  };

  config = mkIf cfg.enable {
    services.nix-daemon = enabled;
  };
}
