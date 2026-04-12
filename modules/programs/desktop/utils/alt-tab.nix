_: {
  rbn.programs._.desktop._.utils._.alt-tab.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.alt-tab-macos ];
    };
}
