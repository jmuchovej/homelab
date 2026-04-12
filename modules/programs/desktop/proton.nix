_: {
  rbn.programs._.desktop._.proton = {
    # TODO: needs upstream nixpkg support for protonmail-desktop, protonmail-bridge,
    # protonvpn-cli, proton-pass
    homeManager = { };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "protonvpn" ];
      };
  };
}
