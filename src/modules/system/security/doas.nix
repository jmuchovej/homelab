{
  rbn.system._.security._.doas.nixos =
    {
      user,
      lib,
      pkgs,
      ...
    }:
    {
      security.sudo.enable = lib.mkForce false;

      environment.systemPackages = [
        pkgs.doas-sudo-shim
      ];

      security.doas = {
        enable = true;
        extraRules = [
          {
            users = [ user.userName ];
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
