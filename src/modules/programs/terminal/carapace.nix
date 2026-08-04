{
  rbn.programs._.terminal._.carapace.hm = { pkgs, ... }: {
    home.packages = [ pkgs.carapace-bridge ];

    programs.carapace.enable = true;
  };
}
