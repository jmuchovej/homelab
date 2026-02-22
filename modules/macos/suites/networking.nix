{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.networking";
  imports = [ (lib.rebellion.fs.get-file "modules/common/suites/networking.nix") ];
}
