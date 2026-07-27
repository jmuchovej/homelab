{
  rbn.programs._.toolchains._.development.homeManager =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      home.packages = with pkgs; [
        devenv
        pre-commit
        prek
        treefmt
        tokei
        onefetch
        act

        nix-tree
        nix-du
        graphviz

        (writeShellScriptBin "closure-size" ''
          nix path-info --recursive --closure-size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')

        (writeShellScriptBin "store-size" ''
          nix path-info --recursive --size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')
      ];

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableZshIntegration = config.programs.zsh.enable;
        enableNushellIntegration = config.programs.nushell.enable;
      };

      # environment.sessionVariables.DIRENV_LOG_FORMAT = ""; # Blank so direnv will shut up

      home.shellAliases =
        let
          nr-bin = lib.getExe pkgs.nixpkgs-review;
        in
        {
          prefetch-sri = "nix store prefetch-file $1";
          nrh = "${nr-bin} rev HEAD";
          nra = ''${nr-bin} pr $1 --systems "all"'';
          nrap = ''${nr-bin} pr $1 --systems "all" --post-result --num-parallel-evals 4'';
          nrd = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2'';
          nrdp = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2 --post-result'';
          nrl = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2'';
          nrlp = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2 --post-result'';
          nrmp = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin aarch64-linux" --num-parallel-evals 3 --post-result'';
          nup = "nix-shell maintainers/scripts/update.nix --argstr package $1";
          num = "nix-shell maintainers/scripts/update.nix --argstr maintainer $1";
        };
    };
}
