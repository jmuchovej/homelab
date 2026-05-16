_: {
  rbn.programs._.browsers._.arc = {
    # arc-browser removed from nixpkgs — only available via homebrew on macOS
    homeManager = { };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "arc" ];
      };
  };
}
