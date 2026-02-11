{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "security.sops";
  options =
    { lib, ... }:
    {
      defaultSopsFile = lib.mkOption {
        type = lib.types.path;
        description = "Default sops file.";
      };
      sshKeyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ "/etc/ssh/ssh_host_ed25519_key" ];
        description = "SSH Key paths to use.";
      };
    };
  config =
    { cfg, ... }:
    {
      sops = {
        inherit (cfg) defaultSopsFile;

        age = {
          inherit (cfg) sshKeyPaths;
        };
      };
    };
}
