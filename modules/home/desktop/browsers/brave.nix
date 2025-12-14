{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.rebellion.desktop.brave;
in
{
  options.rebellion.desktop.brave = {
    enable = mkEnableOption "Brave";
  };

  config = mkIf cfg.enable {
    programs.brave = {
      enable = true;

      # extensions = with pkgs.chromium-extensions; [
      #   catppuccin.catppuccin-vsc
      #   eamodio.gitlens
      #   formulahendry.auto-close-tag
      #   formulahendry.auto-rename-tag
      #   github.chromium-github-actions
      #   github.chromium-pull-request-github
      #   gruntfuggly.todo-tree
      #   mkhl.direnv
      #   chromium-icons-team.vscode-icons
      #   wakatime.chromium-wakatime
      # ];
    };
  };
}
