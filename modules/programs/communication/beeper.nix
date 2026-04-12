_: {
  rbn.programs._.communication._.beeper = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          beeper-bridge-manager
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "beeper" ];
      };
  };
}
