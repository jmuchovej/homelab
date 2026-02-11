{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.tmux";
  description = "tmux";
  config =
    { lib, ... }:
    let
      inherit (builtins) concatStringsSep map;
      inherit (lib.strings) fileContents;
      inherit (lib.rebellion) get-files;

      configFiles = get-files ./tmux;
    in
    {
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
