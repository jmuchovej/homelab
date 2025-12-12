{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (builtins) concatStringsSep map;
  inherit (lib) mkIf mkEnableOption;
  inherit (lib.strings) fileContents;

  cfg = config.rebellion.programs.tools.tmux;
  configFiles = lib.snowfall.fs.get-files ./config;
in {
  options.rebellion.programs.tools.tmux = {
    enable = mkEnableOption "tmux";
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      aggressiveResize = true;
      baseIndex = 1;
      clock24 = true;
      escapeTime = 0;
      historyLimit = 2000;
      keyMode = "vi";
      newSession = true;
      shortcut = "`";
      terminal = "xterm-256color";
      extraConfig = concatStringsSep "\n" (map fileContents configFiles);
    };
  };
}
