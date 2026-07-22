_: {
  rbn.services._.provides._.github-runner = {
    nixos =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      {
        services.github-runners.${host} = {
          enable = true;
          name = host;
          ephemeral = false;
          replace = true;
          extraLabels = [ "nixos" ];
        };
      };
  };
}
