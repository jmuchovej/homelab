{
  options,
  config,
  lib,
  host,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf types optional;
  inherit (builtins) elemAt;
  inherit (lib.strings) splitString;
  inherit (lib.${namespace}) enabled;
  inherit (lib.snowfall.fs) get-file;

  cfg = config.${namespace}.suites.cluster;
  datacenter = elemAt 0 (splitString "-" host);
  sopsFile = get-file "secrets/${datacenter}.sops.yaml";
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
    isFirst = mkEnableOption "set as 'first'.";
    leader  = mkOption {
      type = nullOr str;
      default = null;
      description = "Hostname of the lead server in a multi-node setup.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.isFirst && cfg.leader != null;
      message = "Cannot both be `first` **and** need a `leader` to connect to!";
    }];

    sops."k3s/token".sopsFile = sopsFile;

    services.k3s = enabled // {
      inherit (cfg) role;
      tokenFile = config.sops."k3s/token".path;
      clusterInit = cfg.isFirst;
      serverAddr = optional (!cfg.isFirst) cfg.leader;
    };
  };
}
