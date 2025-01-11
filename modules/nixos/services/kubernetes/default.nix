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

  cfg = config.${namespace}.services.kubernetes;
  datacenter = elemAt (splitString "-" host) 0;
  sopsFile = get-file "secrets/${datacenter}.sops.yaml";
in
{
  options.${namespace}.services.kubernetes = with types; {
    enable = mkEnableOption "kubernetes";
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
      assertion = (!cfg.isFirst && cfg.leader == null) || (cfg.isFirst && cfg.leader != null);
      message = "Cannot both be `first` **and** need a `leader` to connect to!";
    }];

    sops.secrets."k8s/token" = {
      inherit sopsFile;
    };

    services.k3s = enabled // {
      inherit (cfg) role;
      tokenFile = config.sops.secrets."k8s/token".path;
      clusterInit = cfg.isFirst;
      serverAddr = mkIf (!cfg.isFirst && cfg.leader != null) cfg.leader;
    };
  };
}
