_: {
  rbn.programs._.documents._.logseq = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.logseq ];

        rebellion.dock.entries = [
          {
            name = "Logseq.app";
            source = "applications";
            group = "pkm";
            order = 440;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "logseq" ];
      };
  };
}
