{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.common";
  config =
    { lib, ... }:
    {
    };
}
