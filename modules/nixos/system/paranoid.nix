{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkForce;

  cfg = config.rebellion.system.security.lockdown;
in
{
  options.rebellion.system.security.lockdown = {
    enable = mkEnableOption "lockdown the system for maximum security";
  };

  config = mkIf cfg.enable {
    # Ripped from:
    # https://xeiaso.net/blog/paranoid-nixos-2021-07-18/

    nix.allowedUsers = [ "@wheel" ];
    environment.defaultPackages = mkForce [ ]; # Heres a great little piece, it disables any non defined packages for this system

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
