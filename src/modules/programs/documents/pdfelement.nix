_: {
  rbn.programs._.documents._.pdfelement.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "pdfelement" ];
    };
}
