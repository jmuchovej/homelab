{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.social";
  config = { lib, ... }: { };
}
