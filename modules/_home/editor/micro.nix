{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "editor.micro";
  options =
    let
      inherit (lib.rebellion.options) mk-enable';
    in
    {
      default = mk-enable' "`micro` as the default $EDITOR";
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
        mkForce
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

      programs.bash.shellAliases.vimdiff = mkIf cfg.default.enable "micro -d";
      programs.fish.shellAliases.vimdiff = mkIf cfg.default.enable "micro -d";
      programs.zsh.shellAliases.vimdiff = mkIf cfg.default.enable "micro -d";

      home.sessionVariables = {
        EDITOR = mkIf cfg.default.enable (mkForce "micro");
      };

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
