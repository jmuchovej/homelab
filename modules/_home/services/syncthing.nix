{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "services.syncthing";
  config =
    { cfg, config, ... }:
    {
      services.syncthing = {
        enable = true;

        extraOptions = [
          "-data-dir=${config.rebellion.user.home}/Syncthing"
        ];
      };
    };
}
