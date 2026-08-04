{
  rbn.shells._.nushell = {
    os = { pkgs, ... }: {
      environment.shells = [ pkgs.nushell ];
    };

    hm = { config, lib, ... }: {
      home.shell.enableNushellIntegration = true;
      programs.nushell = {
        enable = true;
        shellAliases = lib.filterAttrs (_k: v: !lib.hasInfix " && " v) config.home.shellAliases;
      };
    };
  };
}
