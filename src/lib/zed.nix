{
  lib ? { },
  rebellion-lib ? { },
  inputs ? { },
}:
{
  zed = {
    mk-zed-settings =
      {
        extensions ? [ ],
        packages ? [ ],
        settings ? { },
      }:
      {
        inherit extensions;
        extraPackages = packages;
        userSettings = settings;
      };
  };
}
