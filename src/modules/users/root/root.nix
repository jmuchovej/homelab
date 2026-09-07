{ den, ... }: {
  den.aspects.root = { config, ... }: {
    includes = [
      den.aspects.tools.nix-trusted-user
    ];

    meta = {
      authorized-keys = [ ];
    };

    nixos = {
      users.users.root = {
        openssh.authorizedKeys.keys = config.meta.authorized-keys;
      };
    };
  };
}
