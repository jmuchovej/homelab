{ __findFile, ... }:
{
  den.aspects.lab = {
    includes = [
      # <rbn/shell>
    ];

    nixos.users.users.lab = { };
  };

  den.hosts.x86_64-linux.da-vcx-1.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-2.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-3.users.lab = { };

  den.hosts.x86_64-linux.en-t65-1.users.lab = { };
}
