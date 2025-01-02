{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption optionalString;

  cfg = config.${namespace}.programs.tools.onepassword-cli;
in
{
  options.${namespace}.programs.tools.onepassword-cli = {
    enable = mkEnableOption "1password-cli";
    enableSshSocket = mkEnableOption "1password's ssh-agent socket";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs._1password-cli ];

    programs = {
      ssh.extraConfig = optionalString cfg.enableSshSocket ''
        Host *
          AddKeysToAgent yes
          IdentityAgent ~/.1password/agent.sock
      '';
    };
  };
}
