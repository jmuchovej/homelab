{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.editor.micro;
in {
  options.${namespace}.editor.micro = {
    enable = mkEnableOption "micro";
    default = mkEnableOption "micro as the default $EDITOR";
  };

  config = mkIf cfg.enable {
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
      source = lib.cleanSourceWith {
        filter = name: _type: let
          baseName = baseNameOf (toString name);
        in
          lib.hasSuffix ".micro" baseName;
        src = lib.cleanSource ./.;
      };

      recursive = true;
    };
  };
}
