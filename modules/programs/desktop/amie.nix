_: {
  rbn.programs._.desktop._.amie.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "amie" ];
    };
}
