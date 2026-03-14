{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "system";
  description = "manage locale settings";
  config =
    { lib, ... }:
    {
      environment.variables = {
        # Set locale archive variable in case it isn't being set properly
        LOCALE_ARCHIVE = "/run/current-system/sw/lib/locale/locale-archive";
      };

      i18n.defaultLocale = "en_US.UTF-8";

      console = {
        font = "Lat2-Terminus16";
        keyMap = lib.mkForce "us";
      };
    };
}
