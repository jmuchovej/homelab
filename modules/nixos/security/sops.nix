{
  config,
  lib,
  host,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkEnableOption
    mkOption
    ;

  cfg = config.rebellion.security.sops;
  default-sops-file = lib.rebellion.file.get-file "secrets/systems/${host}.sops.yaml";
in
{
  options.rebellion.security.sops = with types; {
    enable = mkEnableOption "sops";
    defaultSopsFile = mkOption {
      type = path;
      default = default-sops-file;
      description = "Default sops file.";
    };
    sshKeyPaths = mkOption {
      type = listOf path;
      default = [ "/etc/ssh/ssh_host_ed25519_key" ];
      description = "SSH Key paths to use.";
    };
  };

  config = mkIf cfg.enable {
    sops = {
      inherit (cfg) defaultSopsFile;

      age = {
        inherit (cfg) sshKeyPaths;
        generateKey = false; # This is already done with the host key
      };
    };
  };
}
