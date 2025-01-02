{
  config,
  inputs,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption optionals getExe getExe';
  inherit (lib.${namespace}) mkNestedEnableOption enabled;
  inherit (lib.types) submodule;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (inputs) snowfall-flake;
  inherit (lib.${namespace}) get-shared;

  cfg     = config.${namespace}.suites.development;
  # desktop = config.${namespace}.suites.desktop;

  nr-bin = getExe pkgs.nixpkgs-review;
in
{
  options.${namespace}.suites.development = {
    enable  = mkEnableOption "`development` configuration";
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      tokei     # Code statistics
      treefmt2  # Multi-language formatter
      onefetch
      postman
      bruno
      act
      dbeaver-bin
    ]);

    home.shellAliases = {
      prefetch-sri = "nix store prefetch-file $1";
      nrh   = ''${nr-bin} rev HEAD'';
      nra   = ''${nr-bin} pr $1 --systems "all"'';
      nrap  = ''${nr-bin} pr $1 --systems "all" --post-result --num-parallel-evals 4'';
      nrd   = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2'';
      nrdp  = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2 --post-result'';
      nrl   = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2'';
      nrlp  = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2 --post-result'';
      # TODO: remove once remote building to khanelinix works
      nrmp  = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin aarch64-linux" --num-parallel-evals 3 --post-result'';
      nup   = ''nix-shell maintainers/scripts/update.nix --argstr package $1'';
      num   = ''nix-shell maintainers/scripts/update.nix --argstr maintainer $1'';
    };

    ${namespace} = {
      programs = {
        editors = {
          vscode = {
            enable = mkDefault config.${namespace}.suites.desktop.enable;
          };
          zed = {
            enable = mkDefault config.${namespace}.suites.desktop.enable;
          };
          helix = enabled;
          neovim = {
            enable  = mkDefault true;
            default = mkDefault true;
          };
          micro = enabled;
        };

        tools = {
          k9s     = enabled;
          gh      = enabled;
          lazygit = mkDefault enabled;
        };
      };
    };
  };
}
