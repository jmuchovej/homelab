{
  den.aspects.tools._.nix-trusted-user = {
    ox = { user, ... }: {
      nix.settings.trusted-users = [ user.userName ];
    };
  };
}
