{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "editor.micro";
  options = with lib.rebellion; {
    default = mkopt-enable "micro as the default $EDITOR";
  };
  config =
    {
      cfg,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkIf
        cleanSourceWith
        cleanSource
        hasSuffix
        ;
    in
    {
      programs.micro = {
        enable = true;
        settings = {
          colorscheme = "catppuccin-macchiato";
        };
      };

      programs.bash.shellAliases.vimdiff = mkIf cfg.default "micro -d";
      programs.fish.shellAliases.vimdiff = mkIf cfg.default "micro -d";
      programs.zsh.shellAliases.vimdiff = mkIf cfg.default "micro -d";

      # home.sessionVariables = {
      #   EDITOR = mkIf cfg.default "micro";
      # };

      xdg.configFile."micro/colorschemes" = {
        source = cleanSourceWith {
          filter =
            name: _type:
            let
              baseName = baseNameOf (toString name);
            in
            hasSuffix ".micro" baseName;
          src = cleanSource ./.;
        };

        recursive = true;
      };
    };
}
