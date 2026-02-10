{
  config,
  lib,
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
in
{
  options.rebellion.security.sops = with types; {
    enable = mkEnableOption "sops";
    defaultSopsFile = mkOption {
      type = path;
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
      };
    };
  };
}
