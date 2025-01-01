{ config, lib, pkgs, namespace, ...  }: let
  inherit (lib) mkIf mkDefault;
  inherit (lib.${namespace}) get-shared enabled;

  cfg = config.${namespace}.suites.common;
in
{
  imports = [
    (get-shared "suites/common")
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = (with pkgs; [
      gawk
      gnugrep
      gnupg
      gnused
      gnutls
      mas
      terminal-notifier
      trash-cli
      wtf
    ]);

    ${namespace} = {
      home.extraOptions = {
        home.shellAliases = {
          # Prevent shell log command from overriding macos log
          log = ''command log'';
        };
      };

      nix       = mkDefault enabled;
      homebrew  = mkDefault enabled;

      system    = {
        fonts       = mkDefault enabled;
        input       = mkDefault enabled;
        interface   = mkDefault enabled;
        networking  = mkDefault enabled;
      };

      services = {
        nix-daemon  = enabled;
      };
    };
  };
}
