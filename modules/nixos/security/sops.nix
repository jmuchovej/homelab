{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "security.sops";
  description = "sops";
  options =
    { lib, host, ... }:
    let
      inherit (lib) mkOption types;
      default-sops-file = lib.rebellion.file.get-file "secrets/systems/${host}.sops.yaml";
    in
    {
      default-sops-file = mkOption {
        type = types.path;
        default = default-sops-file;
        description = "Default sops file.";
      };
      ssh-key-paths = mkOption {
        type = types.listOf types.path;
        default = [ "/etc/ssh/ssh_host_ed25519_key" ];
        description = "SSH Key paths to use.";
      };
    };
  config =
    { cfg, ... }:
    {
      sops = {
        defaultSopsFile = cfg.default-sops-file;

        age = {
          sshKeyPaths = cfg.ssh-key-paths;
          generateKey = false; # This is already done with the host key
        };
      };
    };
}
