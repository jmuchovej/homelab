_: {
  rbn.programs._.development._.powershell = {
    homeManager =
      { pkgs, lib, ... }:
      lib.mkIf pkgs.stdenv.isLinux {
        home.packages = [ pkgs.powershell ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "powershell" ];
      };
  };
}
