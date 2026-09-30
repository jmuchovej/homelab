{ lib, pkgs, ... }:
let
  argv = lib.splitString " ";
in
{
  _rbn-lib = {
    inherit argv;
  };
}
