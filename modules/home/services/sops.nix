{
  config,
  lib,
  namespace,
  pkgs,
  options,
  ...
}:
let
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    ;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.services.sops;
  username = config.rebellion.user.name;
  default-sops-file = get-file "secrets/homes/${username}.sops.yaml";
in
{
  options.rebellion.services.sops = with types; {
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
    home.packages = with pkgs; [
      age
      sops
      ssh-to-age
    ];

    sops = {
      inherit (cfg) defaultSopsFile;
      defaultSopsFormat = "yaml";

      age = {
        generateKey = true;
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ] ++ cfg.sshKeyPaths;
      };

      secrets."nix".path = "${config.home.homeDirectory}/.config/nix/nix.conf";
    };
  };
}
