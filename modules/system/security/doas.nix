_: {
  rbn.system._.security._.doas.nixos =
    {
      host,
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
            users = [ host.user.name ];
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
