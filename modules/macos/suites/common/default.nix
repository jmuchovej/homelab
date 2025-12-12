{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.rebellion) get-file enabled;

  cfg = config.rebellion.suites.common;
in
{
  imports = [
    (get-file "modules/shared/suites/common/default.nix")
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

      nix = mkDefault enabled;
      homebrew = mkDefault enabled;

      system = {
        fonts = mkDefault enabled;
        input = mkDefault enabled;
        interface = mkDefault enabled;
        networking = mkDefault enabled;
      };

      # services = {
      #   nix-daemon = enabled;
      # };
    };
  };
}
