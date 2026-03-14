{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.common";
  always-active = true;
  imports = [ (lib.rebellion.fs.get-file "modules/_common/suites/common.nix") ];
  config =
    { lib, pkgs, ... }:
    let
      inherit (lib) mkDefault;
      inherit (lib.rebellion) enabled;
    in
    {
      environment.systemPackages = with pkgs; [
        gawk
        gnugrep
        gnupg
        gnused
        gnutls
        terminal-notifier
        trash-cli
      ];

      rebellion = {
        home.extraOptions = {
          home.shellAliases = {
            log = "command log";
          };
        };

        homebrew = mkDefault enabled;

        system = {
          nix = mkDefault enabled;
          fonts = mkDefault enabled;
          input = mkDefault enabled;
          interface = mkDefault enabled;
          networking = mkDefault enabled;
        };
      };
    };
}
