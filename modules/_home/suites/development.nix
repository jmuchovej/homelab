{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.development";
  config = { lib, ... }: { };
}
