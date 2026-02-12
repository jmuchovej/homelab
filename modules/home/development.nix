{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development";
  config =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) getExe;

      nr-bin = getExe pkgs.nixpkgs-review;
    in
    {
      home.packages = with pkgs; [
        tokei # Code statistics
        treefmt # Multi-language formatter
        onefetch
        postman
        bruno
        act
        dbeaver-bin
      ];

      rebellion.dock.entries = [
        {
          name = "Bruno.app";
          source = "hm";
          group = "editors";
          order = 520;
        }
      ];

      home.shellAliases = {
        prefetch-sri = "nix store prefetch-file $1";
        nrh = "${nr-bin} rev HEAD";
        nra = ''${nr-bin} pr $1 --systems "all"'';
        nrap = ''${nr-bin} pr $1 --systems "all" --post-result --num-parallel-evals 4'';
        nrd = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2'';
        nrdp = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2 --post-result'';
        nrl = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2'';
        nrlp = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2 --post-result'';
        # TODO: remove once remote building to khanelinix works
        nrmp = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin aarch64-linux" --num-parallel-evals 3 --post-result'';
        nup = "nix-shell maintainers/scripts/update.nix --argstr package $1";
        num = "nix-shell maintainers/scripts/update.nix --argstr maintainer $1";
      };
    };
}
