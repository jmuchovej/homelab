_: {
  rbn.programs._.terminal._.readline.homeManager =
    { lib, ... }:
    {
      programs.readline = {
        enable = lib.mkDefault true;
        extraConfig = ''
          set completion-ignore-case on
        '';
      };
    };
}
