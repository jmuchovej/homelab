{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "services.ssh-agent";
  config =
    { cfg, ... }:
    {
      services.ssh-agent = {
        enable = true;
      };
    };
}
