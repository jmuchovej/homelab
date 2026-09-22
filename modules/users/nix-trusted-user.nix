{
  den.aspects.tools._.nix-trusted-user = {
    os = { user, ... }: {
      nix.settings.trusted-users = [ user.userName ];
    };
  };
}
