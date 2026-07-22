_: {
  rbn.programs._.development._.powershell = {
    homeManager =
      { pkgs, lib, ... }:
      lib.mkIf pkgs.stdenv.isLinux {
        home.packages = [ pkgs.powershell ];
      };

    darwin.homebrew.casks = [ "powershell" ];
  };
}
