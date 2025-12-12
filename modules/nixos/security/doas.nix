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
  inherit (lib) mkEnableOption;
  cfg = config.rebellion.security.doas;
in
{
  options.rebellion.security.doas = {
    enable = mkEnableOption "`doas` (`sudo` replacement)";
  };

  config = mkIf cfg.enable {
    # Disable sudo
    security.sudo.enable = false;

    environment.systemPackages = [
      pkgs.doas-sudo-shim
    ];

    # Enable and configure `doas`.
    security.doas = {
      enable = true;
      extraRules = [
        {
          users = [ config.rebellion.user.name ];
          noPass = true;
          keepEnv = true;
        }
      ];
    };

    # Add an alias to the shell for backward-compat and convenience.
    environment.shellAliases = {
      sudo = "doas";
    };
  };
}
