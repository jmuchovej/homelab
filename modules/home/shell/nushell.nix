{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "shell.nushell";
  config =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) filterAttrs;
      inherit (lib.strings) hasInfix;
    in
    {
      programs.nushell = {
        enable = true;

        shellAliases = filterAttrs (_k: v: !hasInfix " && " v) config.home.shellAliases;
      };
    };
}
