{
  options,
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.suites.common;
in
{
  options.${namespace}.suites.common = with types; {
    enable = mkEnableOption "`common` suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      hardware = {
        networking = enabled;
      };

      system = {
        nix     = enabled;
        boot    = enabled;
        locale  = enabled;
      };

      services = {
        ssh = enabled;
      };

      security = {
        sops = enabled;
      };
    };
  };
}
