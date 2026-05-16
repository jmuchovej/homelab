_: {
  rbn.shells._.nushell = {
    os = { pkgs, ... }: {
      environment.shells = [ pkgs.zsh ];
    };
    homeManager =
      { config, lib, ... }:
      let
        inherit (lib) filterAttrs;
        inherit (lib.strings) hasInfix;
      in
      {
        programs.nushell = {
          enable = true;
          shellAliases = filterAttrs (_k: v: !hasInfix " && " v) config.home.shellAliases;
        };
      };
  };
}
