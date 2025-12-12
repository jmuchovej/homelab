{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.rebellion;
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.suites.cluster;
in
{
  options.rebellion.suites.cluster = with types; {
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
    rebellion = {
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
