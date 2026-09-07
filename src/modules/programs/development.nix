{ __findFile, ... }: {
  rbn.programs._.development = {
    includes = [
      <rbn/programs/terminal/devenv>
      <rbn/programs/terminal/direnv>
      <rbn/programs/terminal/mise>
      <rbn/programs/terminal/git>
      <rbn/programs/terminal/github>
      <rbn/programs/terminal/jujutsu>
      <rbn/programs/terminal/just>
      <rbn/programs/terminal/treefmt>
    ];

    hm = { pkgs, ... }: {
      home.packages = with pkgs; [
        tokei
        onefetch

        delta
        difftastic

        (writeShellScriptBin "closure-size" ''
          nix path-info --recursive --closure-size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')

        (writeShellScriptBin "store-size" ''
          nix path-info --recursive --size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')
      ];
    };
  };
}
