{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  namespace = "system";
  options =
    { lib, ... }:
    let
      inherit (lib.rebellion.options) mk-enable';
    in
    {
      paranoid = mk-enable' "lockdown";
    };
  description = "lockdown the system for maximum security";
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf cfg.paranoid.enable {
      # Ripped from:
      # https://xeiaso.net/blog/paranoid-nixos-2021-07-18/

      nix.allowedUsers = [ "@wheel" ];
      environment.defaultPackages = lib.mkForce [ ]; # Heres a great little piece, it disables any non defined packages for this system

      services.openssh = {
        passwordAuthentication = false;
        allowSFTP = false; # Don't set this if you need sftp
        challengeResponseAuthentication = false;
        extraConfig = ''
          AllowTcpForwarding yes
          X11Forwarding no
          AllowAgentForwarding no
          AllowStreamLocalForwarding no
          AuthenticationMethods publickey
        '';
      };

      fileSystems."/".options = [ "noexec" ];
      fileSystems."/etc/nixos".options = [ "noexec" ];
      fileSystems."/srv".options = [ "noexec" ];
      fileSystems."/var/log".options = [ "noexec" ];

      environment.systemPackages = with pkgs; [ clamav ]; # PCI Compliance
    };
}
