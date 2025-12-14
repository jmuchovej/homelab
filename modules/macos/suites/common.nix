{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.rebellion) get-file enabled disabled;

  cfg = config.rebellion.suites.common;
in
{
  imports = [
    (get-file "modules/common/suites/common.nix")
  ];

  config = mkIf cfg.enable {
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
          # Prevent shell log command from overriding macOS log
          log = ''command log'';
        };
      };

      homebrew = mkDefault enabled;

      system = {
        nix = mkDefault disabled;
        fonts = mkDefault enabled;
        input = mkDefault enabled;
        interface = mkDefault enabled;
        networking = mkDefault enabled;
      };
    };
  };
}
