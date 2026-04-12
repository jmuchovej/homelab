_: {
  rbn.programs._.communication._.zulip = {
    homeManager =
      { pkgs, lib, ... }:
      lib.mkIf pkgs.stdenv.isLinux {
        home.packages = [ pkgs.zulip ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "zulip" ];
      };
  };
}
