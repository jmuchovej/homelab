{
  rbn.programs._.terminal._.readline.hm = _: {
    programs.readline = {
      enable = true;
      extraConfig = ''
        set completion-ignore-case on
      '';
    };
  };
}
