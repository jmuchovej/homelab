_: {
  rbn.programs._.terminal._.carapace.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.carapace-bridge ];

      programs.carapace = {
        enable = true;
        package = pkgs.carapace;
        ignoreCase = false;

        enableBashIntegration = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
        enableFishIntegration = true;
      };
    };
}
