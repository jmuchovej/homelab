{ __findFile, ... }:
{
  den.aspects.john = {
    includes = [
      <den/primary-user>
      # <rbn/shell>
    ];

    nixos.users.users.john = { };
  };

  den.hosts.x86_64-linux.da-vcx-1.users.john = { };
  den.hosts.x86_64-linux.da-vcx-2.users.john = { };
  den.hosts.x86_64-linux.da-vcx-3.users.john = { };
  den.hosts.aarch64-darwin.da-n1x.users.john = { };

  den.hosts.x86_64-linux.en-t65-1.users.john = { };
}
