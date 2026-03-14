{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.networking";
  imports = [ (lib.rebellion.fs.get-file "modules/_common/suites/networking.nix") ];
}
