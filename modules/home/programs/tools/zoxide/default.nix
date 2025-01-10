{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.zoxide;
in {
  options.${namespace}.programs.tools.zoxide = {
    enable = mkEnableOption "zoxide";
  };

  config = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      package = pkgs.zoxide;
      options = [
        "--cmd z" # Replaces `z` and `zi`
      ];
    };
  };
}
