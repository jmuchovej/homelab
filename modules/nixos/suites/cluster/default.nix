{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.suites.cluster;
in
{
  options.${namespace}.suites.cluster = with types; {
    enable = mkEnableOption "`cluster` suite";
    role = mkOption {
      type = enum [
        "agent"
        "server"
      ];
      default = "server";
      description = "What kind of node is this? (A k3s `server` or `agent`?)";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      suites = {
        server = enabled;
      };

      services = {
        kubernetes = {
          inherit (cfg) role;
          enable = true;
        };
      };
    };
  };
}
