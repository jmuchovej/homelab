{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "security.doas";
  description = "`doas` (`sudo` replacement)";
  config =
    { config, pkgs, ... }:
    {
      security.sudo.enable = lib.mkForce false;

      environment.systemPackages = [
        pkgs.doas-sudo-shim
      ];

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

      environment.shellAliases = {
        sudo = "doas";
      };
    };
}
