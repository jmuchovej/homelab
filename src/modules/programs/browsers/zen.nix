_: {
  rbn.programs._.browsers._.zen.homeManager =
    { pkgs, lib, ... }:
    lib.mkIf pkgs.stdenv.isLinux {
      home.packages = [ pkgs.zen-browser ];
    };
}
