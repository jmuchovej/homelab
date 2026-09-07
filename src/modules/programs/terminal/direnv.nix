{
  rbn.programs._.terminal._.direnv.hm = { pkgs, ... }: {
    programs.direnv = {
      enable = true;
      package = pkgs.direnv;
      nix-direnv.enable = true;
    };
  };
}
