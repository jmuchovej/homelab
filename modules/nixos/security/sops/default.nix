{ config, lib, namespace, host, ...  }:
let
  inherit (lib) types mkIf mkEnableOption mkOption;

  cfg = config.${namespace}.security.sops;
  default-sops-file = (
    lib.snowfall.fs.get-file "secrets/systems/${host}.sops.yaml"
  );
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkEnableOption "sops";
    defaultSopsFile = mkOption {
      type        = path;
      default     = null;
      description = "Default sops file.";
    };
    sshKeyPaths = mkOption {
      type        = (listOf path);
      default     = [ "/etc/ssh/ssh_host_ed25519_key" ];
      description = "SSH Key paths to use.";
    };
  };

  config = mkIf cfg.enable {
    sops = {
      inherit (cfg) defaultSopsFile;

      age = {
        inherit (cfg) sshKeyPaths;
      };
    };

    # sops.secrets = {
    #   "khanelimac_khaneliman_ssh_key" = {
    #     sopsFile = lib.snowfall.fs.get-file "secrets/khanelimac/khaneliman/default.yaml";
    #   };
    # };
  };
}
