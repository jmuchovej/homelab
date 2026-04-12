_: {
  rbn.programs._.documents._.logseq = {
    dock.app = "Logseq.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.logseq ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "logseq" ];
      };
  };
}
