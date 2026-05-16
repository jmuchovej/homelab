_: {
  rbn.programs._.desktop.provides.things = {
    darwin =
      { lib, host, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.masApps = {
          # "Things" = 904280696;
        };
      };
  };
}
